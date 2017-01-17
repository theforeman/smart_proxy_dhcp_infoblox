require 'smart_proxy_dhcp_infoblox/common_crud'

module ::Proxy::DHCP::Infoblox
  class FixedAddressCRUD < CommonCRUD
    def initialize(connection)
      @memoized_hosts = []
      @memoized_condition = nil
      super
    end

    def all_hosts(subnet_address)
      network = ::Infoblox::Fixedaddress.find(@connection, 'network' => subnet_address, '_max_results' => 2147483646) #2**(32-cidr_to_i(subnet_address)))
      network.map {|h| build_reservation(h.name, h, subnet_address)}.compact
    end

    def find_record_by_ip(subnet_address, ip_address)
      found = find_hosts('ipv4addr' => ip_address).first
      return nil if found.nil?
      build_reservation(found.name, found, subnet_address)
    end

    def find_records_by_ip(subnet_address, ip_address)
      found = find_hosts({'ipv4addr' => ip_address}, 2147483646)
      return [] if found.empty?
      found.map {|record| build_reservation(record.name, record, subnet_address)}
    end

    def find_record_by_mac(subnet_address, mac_address)
      found = find_hosts('mac' => mac_address).first
      return nil if found.nil?
      build_reservation(found.name, found, subnet_address)
    end

    def find_hosts(condition, max_results = 1)
      return @memoized_hosts if (!@memoized_host.empty? && @memoized_condition == condition)
      @memoized_condition = condition
      @memoized_hosts = ::Infoblox::Fixedaddress.find(@connection, condition.merge('_max_results' => max_results))
    end

    def find_host_and_name_by_ip(ip_address)
      h = find_hosts('ipv4addr' => ip_address).first
      h.nil? ? [nil, nil] : [h.name, h]
    end

    def build_host(options)
      host = ::Infoblox::Fixedaddress.new(:connection => @connection)
      host.name = options[:hostname]
      host.ipv4addr = options[:ip]
      host.mac = options[:mac]
      # TODO: nextserver, use_nextserver, bootfile, and use_bootfile attrs exist but are not available in the model
      # Might be useful to extend the model to include these
      #host.nextserver = options[:nextServer]
      #host.use_nextserver = true
      #host.bootfile = options[:filename]
      #host.use_bootfile = true
      host
    end
  end
end
