module Proxy::DHCP::Infoblox
  class Plugin < ::Proxy::Provider
    plugin :dhcp_infoblox, ::Proxy::DHCP::Infoblox::VERSION

    default_settings :record_type => 'fixedaddress', :dns_view => "default", :network_view => "default", :blacklist_duration_minutes => 30 * 60
    validate_presence :username, :password

    requires :dhcp, '>= 1.13'

    load_classes ::Proxy::DHCP::Infoblox::PluginConfiguration
    load_validators :record_type_validator => ::Proxy::DHCP::Infoblox::RecordTypeValidator
    load_dependency_injection_wirings ::Proxy::DHCP::Infoblox::PluginConfiguration

    validate :record_type, :record_type_validator => true
  end
end
