module Proxy::DHCP::Infoblox
  class PluginConfiguration
    def load_classes
      require 'infoblox'
      require 'dhcp_common/dhcp_common'
      require 'dhcp_common/free_ips'
      require 'smart_proxy_dhcp_infoblox/host_ipv4_address_crud'
      require 'smart_proxy_dhcp_infoblox/fixed_address_crud'
      require 'smart_proxy_dhcp_infoblox/grid_restart'
      require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'
    end

    def load_dependency_injection_wirings(c, settings)
      c.dependency :connection, (lambda {
        ::Infoblox.wapi_version = '2.0'
        ::Infoblox::Connection.new(:username => settings[:username], :password => settings[:password],
                                   :host => settings[:server],
                                   :ssl_opts => { :verify => !ENV['FOREMAN_INFOBLOX_NOSSLVERIFY'] },
                                   :logger => ::Proxy::LogBuffer::Decorator.instance)
      })

      c.singleton_dependency :unused_ips, lambda { ::Proxy::DHCP::FreeIps.new(settings[:blacklist_duration_minutes]) }

      c.dependency :host_ipv4_crud, (lambda {
        ::Proxy::DHCP::Infoblox::HostIpv4AddressCRUD.new(c.get_dependency(:connection), settings[:dns_view])
      })
      c.dependency :fixed_address_crud, (lambda {
        ::Proxy::DHCP::Infoblox::FixedAddressCRUD.new(c.get_dependency(:connection), settings[:network_view])
      })
      c.dependency :grid_restart, lambda { ::Proxy::DHCP::Infoblox::GridRestart.new(c.get_dependency(:connection)) }
      c.dependency :dhcp_provider, (lambda {
        ::Proxy::DHCP::Infoblox::Provider.new(
          c.get_dependency(:connection),
          c.get_dependency(settings[:record_type] == 'host' ? :host_ipv4_crud : :fixed_address_crud),
          c.get_dependency(:grid_restart),
          c.get_dependency(:unused_ips),
          settings[:subnets],
          settings[:network_view])
      })
    end
  end
end
