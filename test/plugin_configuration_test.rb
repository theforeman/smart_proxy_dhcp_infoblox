require 'test_helper'
require 'infoblox'
require 'dhcp_common/dhcp_common'
require 'smart_proxy_dhcp_infoblox/plugin_configuration'
require 'smart_proxy_dhcp_infoblox/record_type_validator'
require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_plugin'
require 'smart_proxy_dhcp_infoblox/host_ipv4_address_crud'
require 'smart_proxy_dhcp_infoblox/fixed_address_crud'
require 'smart_proxy_dhcp_infoblox/grid_restart'
require 'smart_proxy_dhcp_infoblox/unused_ips'
require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'

class PluginDefaultConfigurationTest < Test::Unit::TestCase
  def test_default_settings
    assert_equal({:record_type => 'host', :range => false, :dns_view => "default", :network_view => "default"},
                 Proxy::DHCP::Infoblox::Plugin.default_settings)
  end
end

class InfobloxDhcpProductionWiringTest < Test::Unit::TestCase
  def setup
    @network_view = "network_view"
    @dns_view = "dns_view"
    @settings = {:username => 'user', :password => 'password', :server => '127.0.0.1', :record_type => 'host',
                 :use_ranges => true, :subnets => ['1.1.1.0/255.255.255.0'],
                 :dns_view => @dns_view, :network_view => @network_view}
    @container = ::Proxy::DependencyInjection::Container.new
    Proxy::DHCP::Infoblox::PluginConfiguration.new.load_dependency_injection_wirings(@container, @settings)
  end

  def test_connection_initialization
    connection = @container.get_dependency(:connection)
    assert_equal 'https://127.0.0.1', connection.host
    assert_equal 'user', connection.username
    assert_equal 'password', connection.password
    assert_equal({:verify => false}, connection.ssl_opts)
  end

  def test_unused_ips_configuration
    free_ips = @container.get_dependency(:unused_ips)
    assert_not_nil free_ips.connection
    assert free_ips.use_ranges
    assert_equal @network_view, free_ips.network_view
  end

  def test_host_ipv4_crud_configuration
    host = @container.get_dependency(:host_ipv4_crud)
    assert_not_nil host.connection
    assert_equal @dns_view, host.dns_view
  end

  def test_fixed_address_crud_configuration
    fixed_address = @container.get_dependency(:fixed_address_crud)
    assert_not_nil fixed_address.connection
    assert_equal @network_view, fixed_address.network_view
  end

  def test_grid_restart_configuration
    grid_restart = @container.get_dependency(:grid_restart)
    assert_not_nil grid_restart.connection
  end

  def test_provider_configuration_with_host_crud
    provider = @container.get_dependency(:dhcp_provider)
    assert_not_nil provider.connection
    assert_not_nil provider.restart_grid
    assert_not_nil provider.unused_ips
    assert_equal @network_view, provider.network_view
    assert provider.managed_subnets.include?('1.1.1.0/255.255.255.0')
    assert provider.crud.instance_of?(::Proxy::DHCP::Infoblox::HostIpv4AddressCRUD)
  end

  def test_provider_configuration_with_fixedaddress_crud
    Proxy::DHCP::Infoblox::PluginConfiguration.new.
        load_dependency_injection_wirings(@container, :username => 'user', :password => 'password',
                                          :server => '127.0.0.1', :record_type => 'fixed_address')

    provider = @container.get_dependency(:dhcp_provider)
    assert provider.crud.instance_of?(::Proxy::DHCP::Infoblox::FixedAddressCRUD)
  end
end
