# SmartProxyDhcpInfoblox

*Introduction here*

This plugin adds a new DHCP provider for managing records with Infoblox Servers

## Installation

See [How_to_Install_a_Smart-Proxy_Plugin](http://projects.theforeman.org/projects/foreman/wiki/How_to_Install_a_Smart-Proxy_Plugin)
for how to install Smart Proxy plugins

This plugin is compatible with Smart Proxy 1.10 or higher.

## Configuration

To enable this DHCP provider, edit `/etc/foreman-proxy/settings.d/dhcp.yml` and set:

    :use_provider: dhcp_infoblox

Configuration options for this plugin are in `/etc/foreman-proxy/settings.d/dhcp_infoblox.yml` and include:

* infoblox_user: API Username
* infoblox_pw: API Password
* infoblox_host: IP/URL to infoblox Server

//// TEMP ////
Add this to the Smart Proxy's bundler.d/Gemfile.local.rb configuration:

  gem 'smart_proxy_dhcp_infoblox', :path => '/path/tosmart_proxy_dhcp_infoblox'

## Contributing

Fork and send a Pull Request. Thanks!

## Copyright

Copyright (c) 2016 Klaas Demter

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

