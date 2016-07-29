require 'dhcp_common/server'
require 'infoblox'
require 'ipaddr'

module Proxy::DHCP::Infoblox
  class Provider < ::Proxy::DHCP::Server
    include Proxy::Log
    include Proxy::Util

    attr_reader :infoblox_user, :infoblox_pw, :server

    def initialize
      # TODO: Verify input
      server = Proxy::DhcpPlugin.settings.server
      infoblox_user = Proxy::DHCP::Infoblox::Plugin.settings.infoblox_user
      infoblox_pw = Proxy::DHCP::Infoblox::Plugin.settings.infoblox_pw
      @record_type = Proxy::DHCP::Infoblox::Plugin.settings.record_type
      @range = Proxy::DHCP::Infoblox::Plugin.settings.range
      @infoblox_subnets = Proxy::DHCP::Infoblox::Plugin.settings.infoblox_subnets
      @restart_sleep = Proxy::DHCP::Infoblox::Plugin.settings.restart_sleep
      @restart = Proxy::DHCP::Infoblox::Plugin.settings.restart
      @managed_subnets = Proxy::DhcpPlugin.settings.subnets
      wapi_version = Proxy::DHCP::Infoblox::Plugin.settings.wapi_version
      ::Infoblox.wapi_version = "#{wapi_version}"
      @connection = ::Infoblox::Connection.new(username: infoblox_user, password: infoblox_pw, host: server)
      logger.debug "Loaded infoblox provider with #{@record_type} record_type and #{wapi_version} wapi_version"
    end

    def initialize_for_testing(params)
      @name = params[:name] || @name
      @service = params[:service] || service
      @dhcp_server = params[:dhcp_server] || @dhcp_server
      @username = params[:username] || @username
      @password = params[:password] || @password
      @record_type = params[:record_type] || @record_type
      @wapi_version = params[:wapi_version] || @wapi_version
      @infoblox_subnets = params[:infoblox_subnets] || @infoblox_subnets
      @restart_sleep = params[:restart_sleep] || @restart_sleep
      @restart = params[:restart] || @restart
      @managed_subnets = params[:managed_subnets] || @managed_subnets
      self
    end

    def restart_services
      ::Infoblox::Grid.all(@connection).first.restartservices
    end

    def load_subnets
      logger.debug 'load_subnets'
      if @infoblox_subnets
        ::Infoblox::Network.all(@connection).each do |obj|
          if match = obj.network.split('/')
            tmp = IPAddr.new(obj.network)
            netmask = IPAddr.new(tmp.instance_variable_get("@mask_addr"), Socket::AF_INET).to_s
            next unless managed_subnet? "#{match[0]}/#{netmask}"
            options = {}
            service.add_subnets(Proxy::DHCP::Subnet.new(match[0], netmask, options))
          end
        end
      else
        @managed_subnets.each do |obj|
          match = obj.split('/')
          options = {}
          service.add_subnets(Proxy::DHCP::Subnet.new(match[0], match[1], options))
        end
      end
    end

    def find_subnet(network_address)
      # returns Proxy::DHCP::Subnet that has network_address or nil if none was found
      # network = ::Infoblox::Ipv4address.find(connection, "ip_address" => network_address).first.network
      super
    end

    def load_subnet_data(subnet)
      # intentionally do nothing
    end

    def load_infoblox_subnet_data(subnet)
      # Load network from infoblox, iterate over ips to gather additional settings
      logger.debug 'load_infoblox_subnet_data'
      if @record_type == 'host'
        # max results are currently set to work in my setup, one could calculate that setting by looking at netmask :)
        network = ::Infoblox::Ipv4address.find(@connection, 'network' => "#{subnet.network}/#{subnet.cidr}", 'status' => 'USED', 'usage' => 'DHCP', '_max_results' => 2**(32-subnet.cidr))
        # Find out which hosts are in use
        network.each do |host|
          # next if certain values are not set
          next if host.names.empty? || host.mac_address.empty? || host.ip_address.empty?
          hostdhcp = ::Infoblox::HostIpv4addr.find(@connection, 'ipv4addr' => host.ip_address).first
          next unless hostdhcp.configure_for_dhcp
          opts = { :hostname => host.names.first }
          opts[:mac] = host.mac_address
          opts[:ip] = host.ip_address
          # broadcast and network entrys are not deleteable
          opts[:deleteable] = true unless (host.types & %w(BROADCAST NETWORK)).any?
          opts[:nextServer] = hostdhcp.nextserver unless hostdhcp.use_nextserver
          opts[:filename] = hostdhcp.bootfile unless hostdhcp.use_bootfile
          service.add_host(subnet.network, Proxy::DHCP::Reservation.new(opts.merge(:subnet => subnet)))
        end
      elsif @record_type == 'fixed_address'
        network = ::Infoblox::Fixedaddress.find(@connection, 'network' => "#{subnet.network}/#{subnet.cidr}", '_max_results' => 2**(32-subnet.cidr))
        network.each do |host|
          logger.debug "Processing host: #{host.name} #{host.mac} #{host.ipv4addr}"
          next if host.name == nil || host.mac == nil || host.ipv4addr == nil
          opts = { :hostname => host.name }
          opts[:mac] = host.mac
          opts[:ip] = host.ipv4addr
          service.add_host(subnet.network, Proxy::DHCP::Reservation.new(opts.merge(:subnet => subnet)))
        end
      end
    end

    def all_hosts(network_address)
      # returns all reservations in a subnet with network_address
      logger.debug "infoblox.all_hosts #{network_address}"
      load_infoblox_subnet_data(find_subnet(network_address))
      super
    end

    def unused_ip(network_address, mac_address, from_ip_address, to_ip_address)
      # returns first available ip address in a network/range with network_address
      logger.debug "Infoblox unused_ip Network_address: #{network_address}, #{mac_address}, #{from_ip_address}, #{to_ip_address}"
      excluded_addresses = []
      if !from_ip_address.nil? and !to_ip_address.nil? and !from_ip_address.empty? and !to_ip_address.empty?
        #next_available_ip can take a number to return (1), and an array of ips to exclude. So, we need to:
        #build a list of all ips in the network (all_addresses)
        #build a list of all ips in between from_ip_address and to_ip_address (include_addresses)
        #remove all of the from_ip_address and to_ip_address from the all_address (exclude_addresses)
        #and call next_available_ip with exclude_addresses passed
        all_addresses = Array.new
        net=IPAddr.new("#{network_address.network}/#{network_address.cidr}")
        net.to_range.each do |ip|
          all_addresses.push(ip.to_s)
        end
        range_start=IPAddr.new(from_ip_address)
        range_stop=IPAddr.new(to_ip_address)
        included_addresses=Array.new
        (range_start..range_stop).each do |ip|
          included_addresses.push(ip.to_s)
        end
        excluded_addresses=all_addresses-included_addresses
        #excluded_addresses is now an array of ips containing all the ips from the network not between from, and to_ip_address
      end

      if @range
        if excluded_addresses.empty?
          ::Infoblox::Range.find(@connection, network: "#{network_address.network}/#{network_address.cidr}").first.next_available_ip(1).first
        else
          ::Infoblox::Range.find(@connection, network: "#{network_address.network}/#{network_address.cidr}").first.next_available_ip(1,excluded_addresses).first
        end
      else
        if excluded_addresses.empty?
          ::Infoblox::Network.find(@connection, network: "#{network_address.network}/#{network_address.cidr}").first.next_available_ip(1).first
        else
          ::Infoblox::Network.find(@connection, network: "#{network_address.network}/#{network_address.cidr}").first.next_available_ip(1,excluded_addresses).first
        end
      end
      # Idea for randomisation in case of concurrent installs:
      #::Infoblox::Network.find(@connection, network: "#{network_address.network}/#{network_address.cidr}").first.next_available_ip(15).sample
    end

    def find_record(subnet_address, an_address)
      logger.debug 'find_record'
      # record can be either ip or mac, true = mac --> lookup ip
      if an_address.is_a?(String) && valid_mac?(an_address)
        if @record_type == 'host'
          hostdhcp = ::Infoblox::HostIpv4addr.find(@connection, 'mac' => an_address)
        elsif @record_type == 'fixed_address'
          hostdhcp = ::Infoblox::Fixedaddress.find(@connection,'mac' => an_address)
        end
        return nil if hostdhcp.empty?
        ipv4address = hostdhcp.first.ipv4addr
      elsif an_address.is_a?(String)
        validate_ip(an_address)
        ipv4address = an_address
      end

      if @record_type == 'host'
        host = ::Infoblox::Host.find(@connection, 'ipv4addr' => ipv4address)
        return nil if host.empty? || host.first.name.empty?
        hostdhcp = ::Infoblox::HostIpv4addr.find(@connection, 'ipv4addr' => ipv4address).first
        return nil unless hostdhcp.configure_for_dhcp
        return nil if hostdhcp.mac.empty? || hostdhcp.ipv4addr.empty?
        opts = { :hostname => host.first.name }
        opts[:mac] = hostdhcp.mac
        opts[:ip] = hostdhcp.ipv4addr
        opts[:deleteable] = true
        opts[:nextServer] = hostdhcp.nextserver if hostdhcp.use_nextserver
        opts[:filename] = hostdhcp.bootfile if hostdhcp.use_bootfile
      elsif @record_type == 'fixed_address'
        logger.debug "find_record for #{an_address}"
        fixed_address = ::Infoblox::Fixedaddress.find(@connection, 'ipv4addr' => ipv4address)
        #logger.debug "#{fixed_address.inspect}"
        return nil if fixed_address == []
        #return nil if fixed_address.emtpy? || fixed_address.first.name.empty?
        #return nil if fixed_address.emtpy?
        opts = { :hostname => fixed_address.first.name }
        opts[:deleteable] = true
        opts[:mac] = fixed_address.first.mac
        opts[:ip] = fixed_address.first.ipv4addr
      end
      # Subnet should only be one, not checking that yet
      subnet = subnets.find { |s| s.include? ipv4address }
      Proxy::DHCP::Record.new(opts.merge(:subnet => subnet))
    end

    def create_infoblox_host_record(record)
      logger.debug 'create_infoblox_host_record'
      host = ::Infoblox::Host.new(:connection => @connection)
      host.name = record.name
      host.add_ipv4addr(record.ip)
      host.post
    end

    def create_infoblox_fixed_address(record)
      logger.debug 'create_infoblox_fixed_address'
      fixed_address = ::Infoblox::Fixedaddress.new(:connection => @connection)
      fixed_address.name = record.name
      fixed_address.ipv4addr = record.ip
      fixed_address.mac = record.mac
      fixed_address.post
    end

    def add_record options={}
      logger.debug 'Add Record'
      record = super
      #Since we support 2 types of records, do the right thing with each one.
      if @record_type == 'host'
        host = ::Infoblox::Host.find(@connection, 'ipv4addr' => record.ip)
        # If empty create:
        if host.empty?
          create_infoblox_host_record(record)
        end
        host = ::Infoblox::Host.find(@connection, 'ipv4addr' => record.ip).first
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
        host.put
      elsif @record_type == 'fixed_address'
        create_infoblox_fixed_address(record)
      end
      if @restart
        restart_services
        sleep @restart_sleep if !@restart_sleep.nil?
      end
      record
    end

    def del_record subnet, record
      logger.debug 'Infoblox del_record'
      validate_subnet subnet
      validate_record record
      # TODO: Refactor this into the base class
      raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?
      if @record_type == 'host'
        # Delete whole host object that includes record.ip
        host = ::Infoblox::Host.find(@connection, 'ipv4addr' => record.ip)
        unless host.empty?
          # if not empty, first element is what we want to delete
          host.first.delete
        end
      elsif @record_type == 'fixed_address'
        #Delete the fixed address record.
        fixed_address = ::Infoblox::Fixedaddress.find(@connection, 'ipv4addr' => record.ip).first
        fixed_address.delete
      end
      restart_services if @restart

      logger.debug "Deleted #{@record_type} on #{record}"
    end
  end
end
