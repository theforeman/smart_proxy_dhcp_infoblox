require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_version'

module Proxy::Dhcp::Infoblox
  class Plugin < ::Proxy::Provider
    plugin :dhcp_infoblox, ::Proxy::Dhcp::Infoblox::VERSION, :factory => proc { |attrs| ::Proxy::Dhcp::Infoblox::Provider.provider(attrs) }

    # Settings listed under default_settings are required.
    # An exception will be raised if they are initialized with nil values.
    # Settings not listed under default_settings are considered optional and by default have nil value.
    default_settings :infoblox_user => 'infoblox', :infoblox_pw => 'infoblox', :infoblox_host => 'infoblox.my.domain'

    requires :dhcp, '>= 1.11'

    #validate_presence :infoblox_user, :infoblox_pw, :infoblox_host

    after_activation do
      require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'
      require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_dependencies'
    end
  end
end
