require 'dhcp_common/free_ips'
require 'smart_proxy_dhcp_infoblox/ip_address_arithmetic'

module Proxy::DHCP::Infoblox
  class FreeIps < ::Proxy::DHCP::FreeIps
    include IpAddressArithmetic
    def find_free_ip(from_address, to_address, network)
      start_addr, end_addr = network_cidr_to_range(network.network)
      start_addr_i = ipv4_to_i(start_addr)
      end_addr_i = ipv4_to_i(end_addr)
      excludes=[]
      for addr in [*start_addr_i..ipv4_to_i(from_address)-1, *ipv4_to_i(to_address)+1..end_addr_i]
        excludes.push(i_to_ipv4(addr))
      end

      @m.synchronize do
        excludes.push(*@allocated_ips.to_a)
        begin
          suggested_ip = network.next_available_ip(1, excludes).first
          mark_ip_as_allocated(suggested_ip)
          return suggested_ip
        rescue Infoblox::Error => e
          raise e unless e.message.include?("Cannot find 1 available IP address")
          raise Proxy::DHCP::Error, "No free address found in subnet #{network.network}"
        end
      end
    end
  end
end
