require 'dhcp_common/server'
require 'infoblox'

module Proxy::DHCP::Infoblox
  class Provider < ::Proxy::DHCP::Server
    include Proxy::Log
    include Proxy::Util

    attr_reader :infoblox_user, :infoblox_pw, :infoblox_host

    def initialize
      super(Proxy::DhcpPlugin.settings.server)
      # TODO: Verify input
      @connection = ::Infoblox::Connection.new(username: @infoblox_user ,password: @infoblox_pw, host: @infoblox_host)
    end

    def initialize_for_testing(params)
      @name = params[:name] || @name
      @service = params[:service] || service
      @dhcp_server = params[:dhcp_server] || @dhcp_server
      @username = params[:username] || @username
      @password = params[:password] || @password
      self
    end

    def load_subnets
      ::Infoblox::Network.all(connection).each do |obj|
        if match = obj.network.split('/')
          tmp = IPAddr.new(obj.network)
          netmask = IPAddr.new(tmp.instance_variable_get("@mask_addr"), Socket::AF_INET).to_s
          next unless managed_subnet? "#{match[0]}/#{netmask}"
          Proxy::DHCP::Subnet.new(self, match[0], netmask)
        end
      end
    end

    def find_subnet(network_address)
      # returns Proxy::DHCP::Subnet that has network_address or nil if none was found
    end

    def load_subnet_data subnet
      # Load network from infoblox, iterate over ips to gather additional settings
      logger.debug "LoadSubnetData"
      super
      network = IPAddr.new(subnet.to_s, Socket::AF_INET)
      # max results are currently set to work in my setup, one could calculate that setting by looking at netmask :)
      network = ::Infoblox::Ipv4address.find(connection, "network" => "#{network}/#{subnet.cidr}", "_max_results" => "2500")
      # Find out which hosts are in use
      network.each do |host|
        # next if certain values are not set
        next if host.names.empty? || host.mac_address.empty? || host.ip_address.empty?
        hostdhcp = ::Infoblox::HostIpv4addr.find(connection, "ipv4addr" => host.ip_address).first
        next unless hostdhcp.configure_for_dhcp
        opts = {:hostname => host.names.first}
        opts[:mac] = host.mac_address
        opts[:ip] = host.ip_address
        # broadcast and network entrys are not deleteable
        opts[:deleteable] = true unless (host.types & ['BROADCAST', 'NETWORK']).any?
        opts[:nextServer] = hostdhcp.nextserver unless hostdhcp.use_nextserver
        opts[:filename] = hostdhcp.bootfile unless hostdhcp.use_bootfile
        Proxy::DHCP::Reservation.new(opts.merge(:subnet => subnet))
      end
    end

    def subnets
      # returns all available subnets (instances of Proxy::DHCP::Subnet)
    end

    def all_hosts(network_address)
      # returns all reservations in a subnet with network_address
    end

    def unused_ip(network_address, mac_address, from_ip_address, to_ip_address)
      # returns first available ip address in a subnet with network_address, for a host with mac_address, in the range of ip addresses: from_ip_address, to_ip_address
    end

    def find_record record
      logger.debug "loadRecord"
      # if record is a String it can be either ip or mac, true = mac --> lookup ip
      if record.is_a?(String) && (IPAddr.new(record) rescue nil).nil?
        hostdhcp = ::Infoblox::HostIpv4addr.find(connection, "mac" => record).first
        ipv4address = hostdhcp.ipv4addr
      elsif record.is_a?(String)
        ipv4address = record
      end
      ipv4address = record[:ip] if record.is_a?(Proxy::DHCP::Record)
      ipv4address = record.to_s if record.is_a?(IPAddr)
      host = ::Infoblox::Host.find(connection, "ipv4addr" => ipv4address).first
      return nil if host.nil? || host.name.empty?
      hostdhcp = ::Infoblox::HostIpv4addr.find(connection, "ipv4addr" => ipv4address).first
      return nil unless hostdhcp.configure_for_dhcp
      return nil if hostdhcp.mac.empty? || hostdhcp.ipv4addr.empty?
      opts = {:hostname => host.name}
      opts[:mac] = hostdhcp.mac
      opts[:ip] = hostdhcp.ipv4addr
      opts[:deleteable] = true
      opts[:nextServer] = hostdhcp.nextserver if hostdhcp.use_nextserver
      opts[:filename] = hostdhcp.bootfile if hostdhcp.use_bootfile
      # Subnet should only be one, not checking that yet
      subnet = subnets.find { |s| s.include? ipv4address}
      Proxy::DHCP::Record.new(opts.merge(:subnet => subnet))
    end

    def add_record options={}
      logger.debug "Add Record"
      record = super(options)
      
      host = ::Infoblox::Host.find(connection, "ipv4addr" => record.ip)
      # If empty create:
      if host.empty?
        logger.debug "Add Record - Create"
        # Create new host object
        host = ::Infoblox::Host.new(:connection => connection)
        host.name = record.name
        host.add_ipv4addr(record.ip)
        post = true
      else
        logger.debug "Add Record - Exists using first element"
        # if not empty, first element is what we want to edit
        host = host.first
        post = false
      end
      options = record.options
      # Overwrite values without checking
      # Select correct ipv4addr object from ipv4addrs array
      hostip = host.ipv4addrs.find { |ip| ip.ipv4addr == record.ip }
      logger.debug "Add Record - record.name: #{record.name}, hostip.host #{hostip.host}, record.mac #{record.mac}, record.ip #{record.ip}"
      logger.debug "Add Record - options[:nextServer] #{options[:nextServer]}, options[:filename] #{options[:filename]}, hostip.ipv4addr: #{hostip.ipv4addr} "
      raise InvalidRecord, "#{record} Hostname mismatch" unless hostip.host == record.name
      hostip.mac = record.mac
      hostip.configure_for_dhcp = true
      hostip.nextserver = options[:nextServer]
      hostip.use_nextserver = true
      hostip.bootfile = options[:filename]
      hostip.use_bootfile = true
      ## Test if Host Entry has correct IP
      raise InvalidRecord, "#{record} IP mismatch" unless hostip.ipv4addr == record.ip
      # Send object
      post ? host.post : host.put
      record
    end

    def del_record subnet, record
     validate_subnet subnet
     validate_record record
     # TODO: Refactor this into the base class
     raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?
     # "Deleting"" a record here means just disabling dhcp
     host = ::Infoblox::Host.find(connection, "ipv4addr" => record.ip)
     unless host.empty?
       # if not empty, first element is what we want to edit
       host = host.first
       # Select correct ipv4addr object from ipv4addrs array
       hostip = host.ipv4addrs.find { |ip| ip.ipv4addr == record.ip }
       hostip.configure_for_dhcp = false
       # Send object
       host.put
     end
     subnet.delete(record)
    end
  end
end
