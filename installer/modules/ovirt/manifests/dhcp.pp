#--
#  Copyright (C) 2008 Red Hat Inc.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# Author: Joey Boggs <jboggs@redhat.com>
#--

import 'augeas'

class dhcp::bundled {

        file {"/etc/dnsmasq.d/ovirt-dhcp.conf":
                content => template("ovirt/ovirt-dhcp.conf.erb"),
                mode => 644,
		notify => Service[dnsmasq],
		require => Package[dnsmasq]
        }

	single_exec {"dns_entries":
                command => "/usr/share/ace/modules/ovirt/files/dns_entries.sh $dhcp_start $dhcp_stop $dhcp_network $dhcp_domain",
                notify => Service[dnsmasq]
	}

        firewall_rule {"tftp": destination_port => '69', protocol => 'udp'}
        firewall_rule {"dhcpd": destination_port => '68', protocol => 'udp'}
        firewall_rule {"bootp": destination_port => '67', protocol => 'udp'}

        augeas {"ip_forwarding":
            context => "/files/etc/sysctl.conf",
            changes => ["set net.ipv4.ip_forward 1"]
        }

        single_exec {"set_ip_fowarding_1":
            command => "/sbin/sysctl -w net.ipv4.ip_forward=1"
        }
}
