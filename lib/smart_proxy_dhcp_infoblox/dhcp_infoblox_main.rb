require 'dhcp_common/server'
require 'infoblox'

module Proxy::Dhcp::Infoblox
  class Provider < ::Proxy::DHCP::Server

    include Proxy::Log
    include Proxy::Util

    def initialize
      ENV['WAPI_VERSION']='2.0'
      @infoblox_user = ::Proxy::Dns::Infoblox::Plugin.settings.infoblox_user
      @infoblox_pw   = ::Proxy::Dns::Infoblox::Plugin.settings.infoblox_pw
      @infoblox_host = ::Proxy::Dns::Infoblox::Plugin.settings.infoblox_host
      @conn          = ::Infoblox::Connection.new(username: @infoblox_user ,password: @infoblox_pw, host: @infoblox_host)
      super('localhost', ::Proxy::Dns::Plugin.settings.dns_ttl)
    end

    def load_subnets
      # loads subnet data into memory
      subnets = Infoblox::Network.all(@conn)
      return subnets
    end

    def find_subnet(network_address)
      # returns Proxy::DHCP::Subnet that has network_address or nil if none was found
    end

    def load_subnet_data(a_subnet)
      # loads lease- and host-records for a Proxy::DHCP::Subnet
    end

    def subnets
      # returns all available subnets (instances of Proxy::DHCP::Subnet)
      subnets = load_subnets
      nets =Array.new
      subnets.each do |s|
        nets.push(Proxy::DHCP::Subnet.new(s.
    end

    def all_hosts(network_address)
      # returns all reservations in a subnet with network_address
    end

    def unused_ip(network_address, mac_address, from_ip_address, to_ip_address)
      # returns first available ip address in a subnet with network_address, for a host with mac_address, in the range of ip addresses: from_ip_address, to_ip_address
    end

    def find_record(network_address, ip_or_mac_address)
      # returns a Proxy::DHCP::Record from a subnet with network_address that has ip- or mac-address specified in ip_or_mac_address, or nil of none was found 
    end

    def add_record(params)
      # creates a record
    end

    def del_record(network_address,a_record)
      # removes a Proxy::DHCP::Record from a subnet with network_address
    end

  end
end
