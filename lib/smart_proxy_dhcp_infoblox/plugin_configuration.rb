module Proxy::DHCP::Infoblox
  class PluginConfiguration
    def load_classes
      require 'infoblox'
      require 'dhcp_common/dhcp_common'
      require 'smart_proxy_dhcp_infoblox/host_ipv4_address_crud'
      require 'smart_proxy_dhcp_infoblox/fixed_address_crud'
      require 'smart_proxy_dhcp_infoblox/grid_restart'
      require 'smart_proxy_dhcp_infoblox/unused_ips'
      require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'
    end

    def load_dependency_injection_wirings(c, settings)


      c.dependency :connection, (lambda do
                                  ::Infoblox.wapi_version = '2.0'
                                  ::Infoblox::Connection.new(:username => settings[:username] ,:password => settings[:password],
                                                             :host => settings[:server], :ssl_opts => {:verify => false})
                                end)


      c.dependency :unused_ips, (lambda do
        ::Proxy::DHCP::Infoblox::UnusedIps.new(c.get_dependency(:connection), settings[:use_ranges],
                                             settings[:network_view])
      end)
      c.dependency :host_ipv4_crud, (lambda do
        ::Proxy::DHCP::Infoblox::HostIpv4AddressCRUD.new(c.get_dependency(:connection), settings[:dns_view])
      end)
      c.dependency :fixed_address_crud, (lambda do
        ::Proxy::DHCP::Infoblox::FixedAddressCRUD.new(c.get_dependency(:connection), settings[:network_view])
      end)
      c.dependency :grid_restart, lambda { ::Proxy::DHCP::Infoblox::GridRestart.new(c.get_dependency(:connection))}
      c.dependency :dhcp_provider, (lambda do
                                      ::Proxy::DHCP::Infoblox::Provider.new(
                                        c.get_dependency(:connection),
                                        settings[:record_type] == 'host' ? c.get_dependency(:host_ipv4_crud) : c.get_dependency(:fixed_address_crud),
                                        c.get_dependency(:grid_restart),
                                        c.get_dependency(:unused_ips),
                                        settings[:subnets],
                                          settings[:network_view])
                                      end)
    end
  end
end

