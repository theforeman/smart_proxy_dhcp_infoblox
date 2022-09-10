module ::Proxy::DHCP::Infoblox
  module IpAddressArithmetic
    def cidr_to_ip_mask(prefix_length)
      bitmask = 0xFFFFFFFF ^ (2**(32 - prefix_length) - 1)
      (0..3).map { |i| (bitmask >> i * 8) & 0xFF }.reverse.join('.')
    end

    def ipv4_to_i(an_address)
      an_address.split('.').inject(0) { |a, c| (a << 8) + c.to_i }
    end

    def i_to_ipv4(i) # rubocop:todo Naming/MethodParameterName
      (0..3).inject([]) { |a, c| a.push((i >> (c * 8)) & 0xFF) }.reverse.join('.')
    end

    def cidr_to_bitmask(prefix_length)
      0xFFFFFFFF ^ (2**(32 - prefix_length) - 1)
    end

    def cidr_to_i(an_address_with_cidr)
      an_address_with_cidr.split("/").last.to_i
    end

    def network_cidr_to_range(network_and_cidr)
      network_addr, cidr = network_and_cidr.split('/')
      mask = cidr_to_bitmask(cidr.to_i)

      range_start = ipv4_to_i(network_addr) & mask
      range_end = range_start | (0xFFFFFFFF ^ mask)

      [i_to_ipv4(range_start), i_to_ipv4(range_end)]
    end
  end
end
