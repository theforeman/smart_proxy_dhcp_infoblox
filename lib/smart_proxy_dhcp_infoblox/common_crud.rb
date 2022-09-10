require 'resolv'
require 'smart_proxy_dhcp_infoblox/ip_address_arithmetic'
require 'smart_proxy_dhcp_infoblox/network_address_range_regex_generator'
require "proxy/validations"

module ::Proxy::DHCP::Infoblox
  class CommonCRUD
    include Proxy::Validations
    include IpAddressArithmetic

    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    def all_leases(network_address, subnet)
      address_range_regex = NetworkAddressesRegularExpressionGenerator.new.generate_regex(network_address)
      ::Infoblox::Lease.find(@connection, 'address~' => address_range_regex).map do |lease|
        # Infoblox can return MAC address set to nil
        next unless lease.hardware

        Proxy::DHCP::Lease.new(
          lease.client_hostname,
          lease.address,
          lease.hardware,
          subnet,
          lease.starts,
          lease.ends,
          lease.binding_state,
          :hostname => lease.client_hostname
        )
      end.compact
    end

    def find_record(subnet_address, an_address)
      return find_record_by_ip(subnet_address, an_address) if Resolv::IPv4::Regex =~ an_address

      find_record_by_mac(subnet_address, an_address)
    end

    def add_record(options)
      validate_ip(options[:ip])
      validate_mac(options[:mac])
      raise(Proxy::DHCP::Error, "Must provide hostname") unless options[:hostname]

      build_host(options).post
      # TODO: DELETE ME needed for testing on infoblox ipam express
      #host.configure_for_dns = false
    rescue Infoblox::Error => e
      raise e unless e.message.include?("IB.Data.Conflict") # not a conflict

      begin
        existing_name, existing_host = find_host_and_name_by_ip(options[:ip])
      rescue Exception
        raise e
      end
      raise e if existing_host.nil? # something weird going on, re-raise the original exception

      if options[:mac] != existing_host.mac || options[:hostname] != existing_name
        raise Proxy::DHCP::Collision, "Record #{options[:ip]} conflicts with an existing record."
      end

      raise Proxy::DHCP::AlreadyExists, "Record #{options[:ip]} already exists."
    end

    def del_record(_, record)
      raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?

      found = find_hosts('ipv4addr' => record.ip).first
      return if found.nil?

      found.delete
    end

    def del_records_by_ip(ip_address)
      found = find_hosts({ 'ipv4addr' => ip_address }, 2147483646)
      return if found.empty?

      found.each { |record| record.delete }
      nil
    end

    def del_record_by_mac(mac_address)
      found = find_hosts('mac' => mac_address).first
      return if found.nil?

      found.delete
      nil
    end

    def build_reservation(name, host, full_subnet_address)
      return nil if host.nil?
      return nil if name.nil? || name.empty?
      return nil if (host.respond_to?(:configure_for_dhcp) && !host.configure_for_dhcp)
      return nil if host.mac.nil? || host.mac.empty?

      opts = { :hostname => name }
      opts[:deleteable] = true
      # TODO: nextserver, use_nextserver, bootfile, and use_bootfile attrs exist but are not available in the Fixedaddress model
      # Might be useful to extend the model to include these
      opts[:nextServer] = host.nextserver if (host.respond_to?(:use_nextserver) && host.use_nextserver)
      opts[:filename] = host.bootfile if (host.respond_to?(:use_bootfile) && host.use_bootfile)
      subnet = ::Proxy::DHCP::Subnet.new(full_subnet_address.split('/').first, cidr_to_ip_mask(cidr_to_i(full_subnet_address.split('/').last)))

      Proxy::DHCP::Reservation.new(name, host.ipv4addr, host.mac, subnet, opts)
    end
  end
end
