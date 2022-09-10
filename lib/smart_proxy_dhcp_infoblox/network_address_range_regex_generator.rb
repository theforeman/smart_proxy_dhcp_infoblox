require 'smart_proxy_dhcp_infoblox/ip_address_arithmetic'

module ::Proxy::DHCP::Infoblox
  class RangeRegularExpressionGenerator
    class Node
      attr_accessor :value, :children

      def initialize(value, children = [])
        @value = value
        @children = children
      end

      def add_children(values)
        return if values.empty?

        node = (found = children.find { |n| n.value == values.first }).nil? ? add_child(Node.new(values.first)) : found
        node.add_children(values[1..-1])
      end

      def <=>(other)
        return -1 if value.to_s == '0?'
        return 1 if other.value.to_s == '0?'
        return 0 if value == other.value
        return -1 if value < other.value

        1
      end

      def add_child(a_node)
        children.push(a_node)
        children.sort!
        a_node
      end

      def group_children
        children.each { |n| n.group_children }
        return if children.size < 2

        @children = children[1..-1].each_with_object([MergedNode.new(children.first)]) do |to_group, grouped|
          current = MergedNode.new(to_group)
          found = grouped.find { |g| ((g.value != ['0?'] && current.value != ['0?']) || (current.value == ['0?'] && g.value == ['0?'])) && (g.children == current.children) }
          found.nil? ? grouped.push(current) : found.merge(current)
        end
      end

      def as_regex
        children.empty? ? [value.to_s] : children.map { |c| c.as_regex.map { |r| value.to_s + r } }.flatten
      end
    end

    class MergedNode
      attr_accessor :value, :children

      def initialize(a_node)
        @value = [a_node.value].flatten
        @children = a_node.children
      end

      def merge(other)
        value.push(other.value).flatten!
        self
      end

      def as_regex
        children.empty? ? [value_as_regex] : children.map { |c| c.as_regex.map { |r| value_as_regex + r } }.flatten
      end

      def value_as_regex
        (value.size < 2) ? value.first.to_s : "[#{value.join('')}]"
      end

      def ==(other)
        return false if self.class != other.class

        value == other.value
      end
    end

    class Root < Node
      def add_number(a_number)
        add_children((['0?', '0?'] + digits(a_number))[-3, 3])
      end

      def as_regex
        group_children
        "(%s)" % children.map { |c| c.as_regex }.join('|')
      end

      def digits(a_number)
        to_return = []
        begin
          to_return.push(a_number % 10)
          a_number /= 10
        end while a_number != 0
        to_return.reverse
      end
    end

    def range_regex(range_start, range_end)
      root = Root.new(nil)
      (range_start..range_end).to_a.each { |i| root.add_number(i) }
      root.as_regex
    end
  end

  class NetworkAddressesRegularExpressionGenerator
    include IpAddressArithmetic

    def generate_regex(network_and_cidr)
      range_to_regex(network_cidr_range_octets(network_and_cidr))
    end

    def network_cidr_range_octets(network_and_cidr)
      range = network_cidr_to_range(network_and_cidr)
      range_start_octets = range.first.split('.').map(&:to_i)
      range_end_octets = range.last.split('.').map(&:to_i)

      (0..3).map { |i| [range_start_octets[i], range_end_octets[i]] }
    end

    def range_to_regex(range)
      range.inject([]) do |a, c|
        start_range, end_range = c
        regex = if start_range == end_range
                  start_range.to_s
                elsif start_range == 0 && end_range == 255
                  '.+'
                else
                  RangeRegularExpressionGenerator.new.range_regex(start_range + 1, end_range - 1)
                end
        a.push(regex)
      end.join('\.')
    end
  end
end
