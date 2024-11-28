require 'smart_proxy_dhcp_infoblox/common_crud'
require 'smart_proxy_dhcp_infoblox/network_address_range_regex_generator'

module ::Proxy::DHCP::Infoblox
  class HostIpv4AddressCRUD < CommonCRUD
    attr_reader :dns_view

    def initialize(connection, dns_view, used_ips_search_type)
      @memoized_hosts = []
      @memoized_condition = nil
      @dns_view = dns_view
      super(connection, used_ips_search_type)
    end

    def all_hosts(subnet_address)
      address_range_regex = NetworkAddressesRegularExpressionGenerator.new.generate_regex(subnet_address)

      if @used_ips_search_type == 'used'
        addresses = ::Infoblox::Ipv4address.find(
          @connection,
          'network' => subnet_address,
          'status' => 'USED',
          '_max_results' => 2147483646
        )
        hosts = addresses.map do |address|
          if address.mac_address.nil? || address.mac_address.empty?
            checked_mac = '00:00:00:00:00:00'
          else
            checked_mac = address.mac_address
          end
          ::Infoblox::Host.new(
            :name => address.names[0],
            :ipv4addrs => [{ :name => address.names[0], :ipv4addr => address.ip_address, :mac => checked_mac,
                             :configure_for_dhcp => true }]
          )
        end
      else
        hosts = ::Infoblox::Host.find(
          @connection,
          'ipv4addr~' => address_range_regex,
          'view' => dns_view,
          '_max_results' => 2147483646
        )
      end

      ip_addr_matcher = Regexp.new(address_range_regex) # pre-compile the regex
      hosts.filter_map do |host|
        build_reservation(host.name, host.ipv4addrs.find { |ip| ip_addr_matcher =~ ip.ipv4addr }, subnet_address)
      end
    end

    def find_record_by_ip(subnet_address, ip_address)
      found = find_hosts('ipv4addr' => ip_address).first
      return nil if found.nil?

      build_reservation(found.name, found.ipv4addrs.find { |ip| ip.ipv4addr == ip_address }, subnet_address)
    end

    def find_records_by_ip(subnet_address, ip_address)
      found = find_hosts({ 'ipv4addr' => ip_address }, 2147483646)
      return [] if found.empty?

      found.filter_map do |record|
        build_reservation(record.name, record.ipv4addrs.find { |ip| ip.ipv4addr == ip_address }, subnet_address)
      end
    end

    def find_record_by_mac(subnet_address, mac_address)
      found = find_hosts('mac' => mac_address).first
      return nil if found.nil?

      build_reservation(found.name, found.ipv4addrs.find { |ip| ip.mac == mac_address }, subnet_address)
    end

    def find_host_and_name_by_ip(ip_address)
      h = find_hosts('ipv4addr' => ip_address).first
      h.nil? ? [nil, nil] : [h.name, h.ipv4addrs.find { |ip| ip.ipv4addr == ip_address }]
    end

    def find_hosts(condition, max_results = 1)
      return @memoized_hosts if (!@memoized_hosts.empty? && @memoized_condition == condition)

      @memoized_condition = condition
      @memoized_hosts = ::Infoblox::Host.find(@connection, condition.merge('view' => dns_view,
                                                                           '_max_results' => max_results))
    end

    def build_host(options)
      host = ::Infoblox::Host.new(:connection => @connection)
      host.name = options[:hostname]
      host_addr = host.add_ipv4addr(options[:ip]).last
      host_addr.mac = options[:mac]
      host_addr.configure_for_dhcp = true
      host_addr.nextserver = options[:nextServer]
      host_addr.use_nextserver = true
      host_addr.bootfile = options[:filename]
      host_addr.use_bootfile = true
      host.view = dns_view
      host
    end
  end
end
