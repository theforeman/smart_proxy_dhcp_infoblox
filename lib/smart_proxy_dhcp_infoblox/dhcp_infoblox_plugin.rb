module Proxy::DHCP::Infoblox
  class Plugin < ::Proxy::Provider
    plugin :dhcp_infoblox, ::Proxy::DHCP::Infoblox::VERSION

    default_settings :record_type => 'fixedaddress',
        :dns_view => "default",
        :network_view => "default",
        :blacklist_duration_minutes => 30 * 60,
        :wait_after_restart => 10,
        :options => []

    validate_presence :username, :password

    requires :dhcp, '>= 3.2'

    load_classes ::Proxy::DHCP::Infoblox::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::DHCP::Infoblox::PluginConfiguration

    validate :record_type, enum: %w[host fixedaddress]
  end
end
