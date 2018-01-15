require 'test_helper'
require 'infoblox'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'

class InfobloxProviderTest < Test::Unit::TestCase
  def setup
    @connection = Object.new
    @crud = Object.new
    @restart_grid = Object.new
    @unused_ips = Object.new
    @managed_subnets = nil
    @network_view = "another"

    @network = Infoblox::Network.new(:network => '192.168.42.0/24')
    @subnet = ::Proxy::DHCP::Subnet.new('192.168.42.0', '255.255.255.0')


    @network_2 = Infoblox::Network.new(:network => '192.168.43.0/24')
    @provider = Proxy::DHCP::Infoblox::Provider.new(@connection, @crud, @restart_grid,
                                                    @unused_ips, @managed_subnets, @network_view)
  end

  def test_subnets
    Infoblox::Network.expects(:all).with(@connection).returns([@network])
    assert_equal [@subnet], @provider.subnets
  end

  def test_subnets_returns_managed_subnets_only
    provider = Proxy::DHCP::Infoblox::Provider.new(@connection, @crud, @restart_grid,
                                                   @unused_ips, ['192.168.42.0/255.255.255.0'], @network_view)
    Infoblox::Network.expects(:all).with(@connection).returns([@network, @network_2])
    assert_equal [@subnet], provider.subnets
  end

  def test_find_subnet
    ::Infoblox::Network.expects(:find).with(@connection, 'network' => '192.168.42.0',
                                            '_max_results' => 1, 'network_view' => @network_view).returns([@network])
    assert_equal @network, @provider.find_network('192.168.42.0')
  end

  def test_find_subnet_raises_exception_when_network_not_found
    ::Infoblox::Network.expects(:find).with(@connection, 'network' => '192.168.42.0',
                                            'network_view' => @network_view, '_max_results' => 1).returns([])
    assert_raises(RuntimeError) { @provider.find_network('192.168.42.0') }
  end

  def test_add_record_restarts_grid
    @crud.stubs(:add_record)
    @provider.stubs(:full_network_address)
    @restart_grid.expects(:try_restart)
    @provider.add_record({})
  end

  def test_del_record_restarts_grid
    @crud.stubs(:del_record)
    @provider.stubs(:full_network_address)
    @restart_grid.expects(:try_restart)
    @provider.del_record(::Proxy::DHCP::Record.new('192.168.42.1', '00:01:02:03:04:05',
                                                   ::Proxy::DHCP::Subnet.new('192.168.42.0', '255.255.255.0')))
  end

  def test_del_record_by_mac_restarts_grid
    @crud.stubs(:del_record_by_mac)
    @restart_grid.expects(:try_restart)
    @provider.del_record_by_mac(@subnet.network, '00:01:02:03:04:05')
  end

  def test_del_record_by_ip_restarts_grid
    @crud.stubs(:del_records_by_ip)
    @restart_grid.expects(:try_restart)
    @provider.del_records_by_ip(@subnet.network, '192.168.42.1')
  end
end
