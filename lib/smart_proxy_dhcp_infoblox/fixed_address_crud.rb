require 'yaml'
require 'smart_proxy_dhcp_infoblox/common_crud'

module ::Proxy::DHCP::Infoblox
  class FixedAddressCRUD < CommonCRUD
    attr_reader :network_view

    def initialize(connection, network_view)
      @memoized_hosts = []
      @memoized_condition = nil
      @network_view = network_view
      super(connection)
    end

    def all_hosts(subnet_address)
      network = ::Infoblox::Fixedaddress.find(@connection, 'network' => subnet_address, 'network_view' => network_view,
                                              '_max_results' => 2147483646)
      network.map { |h| build_reservation(h.name, h, subnet_address) }.compact
    end

    def find_record_by_ip(subnet_address, ip_address)
      found = find_hosts('ipv4addr' => ip_address).first
      return nil if found.nil?

      build_reservation(found.name, found, subnet_address)
    end

    def find_records_by_ip(subnet_address, ip_address)
      found = find_hosts({ 'ipv4addr' => ip_address }, 2147483646)
      return [] if found.empty?

      to_return = found.map { |record| build_reservation(record.name, record, subnet_address) }
      to_return.compact
    end

    def find_record_by_mac(subnet_address, mac_address)
      found = find_hosts('mac' => mac_address).first
      return nil if found.nil?

      build_reservation(found.name, found, subnet_address)
    end

    def find_hosts(condition, max_results = 1)
      return @memoized_hosts if (!@memoized_hosts.empty? && @memoized_condition = condition)

      @memoized_condition = condition
      @memoized_hosts = ::Infoblox::Fixedaddress.find(@connection, condition.merge('_max_results' => max_results,
                                                                                   'network_view' => network_view))
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
      host.nextserver = options[:nextServer]
      host.use_nextserver = true
      host.bootfile = options[:filename]
      host.use_bootfile = true
      host.network_view = network_view
      host.options = Proxy::DHCP::Infoblox::Plugin.settings.options
      host
    end
  end
end
