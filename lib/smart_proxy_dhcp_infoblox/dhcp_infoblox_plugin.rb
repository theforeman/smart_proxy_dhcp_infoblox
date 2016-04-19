require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_version'

module Proxy::DHCP::Infoblox
  class Plugin < ::Proxy::Provider
    plugin :dhcp_infoblox, ::Proxy::DHCP::Infoblox::VERSION, :provider_class => "::Proxy::DHCP::Infoblox::Provider"

    # Settings listed under default_settings are required.
    # An exception will be raised if they are initialized with nil values.
    # Settings not listed under default_settings are considered optional and by default have nil value.
    default_settings :infoblox_user => 'infoblox', :infoblox_pw => 'infoblox', :infoblox_host => 'infoblox.my.domain'

    requires :dhcp, '>= 1.11'

    after_activation do
      require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'
      require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_dependencies'
    end
  end
end
