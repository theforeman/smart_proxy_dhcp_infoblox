require File.expand_path('lib/smart_proxy_dhcp_infoblox/dhcp_infoblox_version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'smart_proxy_dhcp_infoblox'
  s.version     = Proxy::DHCP::Infoblox::VERSION
  s.license     = 'GPL-3.0'
  s.authors     = ['Klaas Demter']
  s.email       = ['demter@atix.de']
  s.homepage    = 'https://github.com/theforeman/smart_proxy_dhcp_infoblox'

  s.summary     = "Infoblox DHCP provider plugin for Foreman's smart proxy"
  s.description = "Infoblox DHCP provider plugin for Foreman's smart proxy"

  s.files       = Dir['{config,lib,bundler.d}/**/*'] + ['README.md', 'LICENSE']
  s.test_files  = Dir['test/**/*']

  s.required_ruby_version = '>= 2.5'

  s.add_runtime_dependency('infoblox', '~> 3.0')

  s.add_development_dependency('rubocop', '~> 0.50.0')
end
