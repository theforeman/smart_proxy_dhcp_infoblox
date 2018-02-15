# SmartProxyDhcpInfoblox

[![Build Status](https://travis-ci.org/theforeman/smart_proxy_dhcp_infoblox.svg?branch=master)](https://travis-ci.org/theforeman/smart_proxy_dhcp_infoblox)

This plugin adds a new DHCP provider for managing records with infoblox servers

## Installation

See [How_to_Install_a_Smart-Proxy_Plugin](http://projects.theforeman.org/projects/foreman/wiki/How_to_Install_a_Smart-Proxy_Plugin)
for how to install Smart Proxy plugins

This plugin is compatible with Smart Proxy 1.11 or higher.

When installing using "gem", make sure to install the bundle file:

    echo "gem 'smart_proxy_dhcp_infoblox'" > /usr/share/foreman-proxy/bundler.d/dhcp_infoblox.rb

## Configuration

To enable this DHCP provider, edit `/etc/foreman-proxy/settings.d/dhcp.yml` and set:

    :use_provider: dhcp_infoblox
    :server: IP of infoblox server
    :subnets: subnets you want to use (optional unless you set infoblox_subnets to false)

Configuration options for this plugin are in `/etc/foreman-proxy/settings.d/dhcp_infoblox.yml` and include:

* username: API Username
* password: API Password
* record_type: host / fixedaddress (see different record types chapter)
* use_ranges: use infoblox ranges (true) or infoblox networks (false) to find the next free ip in your infoblox

## Different record types
The main difference between host and fixedaddress is that a host record already includes the dns records. It's an infoblox object that includes dhcp/a record/ptr records. If you use the host objects there is no need to use a dns smart proxy. Everything gets handled inside the dhcp smart proxy. This does however limit functionality. You can't delete conflicting records or you can't change dns names using foreman gui. Beware when editing host objects manually in infoblox, once you delete a host in foreman all associated host objects get deleted.

If you chose to use fixedaddress you'll need to use the infoblox dns smart proxy (https://github.com/theforeman/smart_proxy_dns_infoblox) if you want to manage dns records.

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

