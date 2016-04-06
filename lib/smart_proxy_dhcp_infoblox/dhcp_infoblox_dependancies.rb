require 'dhcp_common/dependency_injection/dependencies'

class Proxy::Dhcp::DependencyInjection::Dependencies
  dependency :dhcp_provider, Proxy::Dhcp::Infoblox::Provider
end
