require 'test_helper'
require 'infoblox'
require 'dhcp_common/free_ips'
require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'
require 'ostruct'

class UnusedIpTest < Test::Unit::TestCase
  def setup
    @connection = Object.new
    @crud = Object.new
    @restart_grid = Object.new
    @managed_subnets = nil
    @network_view = "another"
    @unused_ips = ::Proxy::DHCP::FreeIps.new
    @network = Infoblox::Network.new(:network => '1.1.1.0/24')
    @provider = Proxy::DHCP::Infoblox::Provider.new(@connection, @crud, @restart_grid,
                                                    @unused_ips, @managed_subnets, @network_view)
  end

  def test_unused_network_ip
    expected_ip = '1.1.1.1'
    @provider.expects(:get_subnet).with('1.1.0.0').returns(::Proxy::DHCP::Subnet.new('1.1.0.0', '255.255.0.0'))
    @provider.expects(:all_hosts).with('1.1.0.0').returns([host = Object.new])
    @provider.expects(:all_leases).with('1.1.0.0').returns([lease = Object.new])
    @unused_ips.expects(:find_free_ip).with('1.1.0.1', '1.1.255.254', [host, lease]).returns(expected_ip)

    ip = @provider.unused_ip('1.1.0.0', nil, nil, nil)

    assert_equal expected_ip, ip
  end

  def test_unused_network_ip_with_mac_address_present
    expected_ip = '1.1.1.1'
    mac_address = '00:01:02:03:04:05'
    @provider.expects(:get_subnet).with('1.1.0.0').returns(subnet = ::Proxy::DHCP::Subnet.new('1.1.0.0', '255.255.0.0'))
    @provider.expects(:find_ip_by_mac_address_and_range).with(subnet, mac_address, '1.1.0.1', '1.1.255.254').returns(expected_ip)

    ip = @provider.unused_ip('1.1.0.0', mac_address, nil, nil)

    assert_equal expected_ip, ip
  end

  def test_unused_network_ip_with_mac_address_present_with_address_outside_range
    expected_ip = '1.1.1.1'
    start_range = '1.1.10.1'
    end_range = '1.1.100.1'
    mac_address = '00:01:02:03:04:05'
    @provider.expects(:get_subnet).with('1.1.0.0').returns(subnet = ::Proxy::DHCP::Subnet.new('1.1.0.0', '255.255.0.0'))
    @crud.expects(:find_record_by_mac).with('1.1.0.0/16', mac_address).returns(OpenStruct.new(:ip => '10.0.0.1'))
    @provider.expects(:all_hosts).with('1.1.0.0').returns([host = Object.new])
    @provider.expects(:all_leases).with('1.1.0.0').returns([lease = Object.new])
    @unused_ips.expects(:find_free_ip).with(start_range, end_range, [host, lease]).returns(expected_ip)

    ip = @provider.unused_ip('1.1.0.0', mac_address, start_range, end_range)

    assert_equal expected_ip, ip
  end
end
