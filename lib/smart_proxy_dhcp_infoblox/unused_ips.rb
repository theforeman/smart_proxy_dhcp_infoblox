require 'ipaddr'
require 'smart_proxy_dhcp_infoblox/ip_address_arithmetic'

module Proxy::DHCP::Infoblox
  class UnusedIps
    include IpAddressArithmetic
    attr_reader :connection, :use_ranges, :network_view

    def initialize(connection, use_ranges, network_view)
      @connection = connection
      @use_ranges = use_ranges
      @memoized_network = nil
      @network_view = network_view
    end

    def unused_ip(network_address, from_ip_address, to_ip_address)
      @use_ranges ? unused_range_ip(network_address, from_ip_address, to_ip_address) : unused_network_ip(network_address, from_ip_address, to_ip_address)
    end

    def unused_network_ip(network_address, from_ip_address, to_ip_address)
      find_network(network_address).next_available_ip(1, excluded_ips(find_network(network_address).network, from_ip_address, to_ip_address)).first
    end

    def unused_range_ip(network_address, from_ip_address, to_ip_address)
      find_range(network_address, from_ip_address, to_ip_address).next_available_ip(1).first
    end

    def excluded_ips(subnet_address, from, to)
      return [] if from.nil? || to.nil?
      (IPAddr.new(network_cidr_to_range(subnet_address).first)..IPAddr.new(network_cidr_to_range(subnet_address).last)).to_a.map(&:to_s) -
          (IPAddr.new(from)..IPAddr.new(to)).to_a.map(&:to_s)
    end

    def find_range(network_address, from, to)
      ranges = ::Infoblox::Range.find(@connection, 'network' => network_address, 'network_view' => network_view)
      range = (from.nil? || to.nil?) ? ranges.first : ranges.find {|r| r.start_addr == from && r.end_addr == to}
      raise "No Ranges found for #{network_address} network" if range.nil?
      range
    end

    def find_network(network_address)
      return @memoized_network if !@memoized_network.nil? && @memoized_address == network_address
      @memoized_address = network_address
      @memoized_network = ::Infoblox::Network.find(@connection, 'network' => network_address, 'network_view' => network_view,
                                                   '_max_results' => 1).first
      raise "Subnet #{network_address} not found" if @memoized_network.nil?
      @memoized_network
    end
  end
end
