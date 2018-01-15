require 'test_helper'
require 'infoblox'
require 'smart_proxy_dhcp_infoblox/unused_ips'

class UnusedIpTest < Test::Unit::TestCase
  def setup
    @connection = Object.new
    @network_view = "another"
    @unused_ips = ::Proxy::DHCP::Infoblox::UnusedIps.new(@connection, false, @network_view)
    @network = Infoblox::Network.new(:network => '1.1.1.0/24')
    @range = Infoblox::Range.new(:start_addr => '1.1.1.0', :end_addr => '1.1.1.253')
  end

  def test_excluded_ips
    assert_equal ['192.168.42.254', '192.168.42.255'], @unused_ips.excluded_ips('192.168.42.0/24', '192.168.42.0', '192.168.42.253')
  end

  def test_excluded_ips_is_empty_when_range_start_is_nil
    assert @unused_ips.excluded_ips('192.168.42.0/24', nil, '192.168.42.253').empty?
  end

  def test_excluded_ips_is_empty_when_range_end_is_nil
    assert @unused_ips.excluded_ips('192.168.42.0/24', '192.168.42.250', nil).empty?
  end

  def test_unused_network_ip
    ::Infoblox::Network.expects(:find).with(@connection, 'network' => '1.1.1.0',
                                            '_max_results' => 1, 'network_view' => @network_view).returns([@network])
    @network.expects(:next_available_ip).with(1, ['1.1.1.254', '1.1.1.255']).returns(['1.1.1.1'])
    assert_equal '1.1.1.1', @unused_ips.unused_network_ip('1.1.1.0', '1.1.1.0', '1.1.1.253')
  end

  def test_unused_range_ip
    ::Infoblox::Range.expects(:find).with(@connection, 'network' => '1.1.1.0', 'network_view' => @network_view).returns([@range])
    @range.expects(:next_available_ip).with(1).returns(['1.1.1.1'])
    assert_equal '1.1.1.1', @unused_ips.unused_range_ip('1.1.1.0', '1.1.1.0', '1.1.1.253')
  end

  def test_unused_ip_uses_network_api_when_use_ranges_is_false
    unused_ips = ::Proxy::DHCP::Infoblox::UnusedIps.new(@connection, false, @network_view)
    unused_ips.expects(:unused_network_ip).with('1.1.1.0', '1.1.1.0', '1.1.1.253')
    unused_ips.unused_ip('1.1.1.0', '1.1.1.0', '1.1.1.253')
  end

  def test_unused_ip_uses_range_api_when_use_ranges_is_true
    unused_ips = ::Proxy::DHCP::Infoblox::UnusedIps.new(@connection, true, @network_view)
    unused_ips.expects(:unused_range_ip).with('1.1.1.0', '1.1.1.0', '1.1.1.253')
    unused_ips.unused_ip('1.1.1.0', '1.1.1.0', '1.1.1.253')
  end
end
