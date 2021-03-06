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

class freeipa::bundled{

	package {"ipa-server":
                ensure => installed,
		require => [Exec[db_exists_file],Single_exec["set_hostname"]]
        }

	single_exec {"set_hostname":
		command => "/bin/hostname $ipa_host",
	}

        single_exec {"set_kdc_defaults":
                command => "/bin/sed -i '/\[kdcdefaults\]/a \ kdc_ports = 88' /usr/share/ipa/kdc.conf.template",
                require => Package[ipa-server]
        }

        single_exec {"replace_line_returns":
                command => "/bin/sed -i -e 's/^/#/' /etc/httpd/conf.d/ipa-rewrite.conf",
                require => Single_Exec[ipa_server_install]
        }

        file_replacement{"ipa_proxy_config_1":
               file => "/etc/httpd/conf.d/ipa.conf",
               pattern => "^<Proxy \*>",
               replacement => "<ProxyMatch ^.*/ipa/ui.*$>",
               require => Single_exec[replace_line_returns]
        }

        file_replacement{"ipa_proxy_config_2":
               file => "/etc/httpd/conf.d/ipa.conf",
               pattern => "^</Proxy>",
               replacement => "</ProxyMatch>",
               require => File_replacement[ipa_proxy_config_1],
               notify => Service[httpd]
        }

	single_exec {"dnsmasq_restart":
                command => "/usr/bin/pkill dnsmasq;/etc/init.d/dnsmasq start",
                require => [Single_exec[add_guest_server_to_etc_hosts],Package[dnsmasq]]
	}

        single_exec {"ipa_server_install":
                command => "/usr/sbin/ipa-server-install -r $realm_name -p '$freeipa_password' -P '$freeipa_password' -a '$freeipa_password' --hostname $ipa_host -u dirsrv -U",
                require => [Single_exec[set_kdc_defaults],Single_exec[dnsmasq_restart]]
        }

        exec {"get_krb5_tkt":
                command => "/bin/echo '$freeipa_password'|/usr/kerberos/bin/kinit admin",
                require => Single_Exec[ipa_server_install]
        }

        single_exec {"ipa_modify_username_length":
		command => "/usr/sbin/ipa-defaultoptions --maxusername=12",
		require => Exec["get_krb5_tkt"]
        }

        single_exec {"ipa_add_ovirtadmin_user":
                command => "/usr/sbin/ipa-adduser -f Ovirt -l Admin -p '$freeipa_password' ovirtadmin",
                require => Single_exec[ipa_modify_username_length]
        }

        single_exec {"ipa_ovirtadmin_group":
                command => "/usr/sbin/ipa-modgroup -a ovirtadmin admins",
                require => Single_exec[ipa_add_ovirtadmin_user]
        }

        single_exec {"set_pw_expiration":
                command => "/usr/sbin/ipa-moduser --setattr krbPasswordExpiration=19700101000000Z ovirtadmin",
                require => Single_exec[ipa_ovirtadmin_group]
        }

       firewall_rule{"krb5": destination_port => "88"}
       firewall_rule {"ldap": destination_port => '389'}
       firewall_rule {"freeip-636": destination_port => '636'}
       firewall_rule {"freeipa-464": destination_port => '464'}
       firewall_rule {"freeipa-88-udp": destination_port => '88', protocol => 'udp'}
       firewall_rule {"freeipa-464-udp": destination_port => '464', protocol => 'udp'}

}

class freeipa::remote {

# oVirt is not configured at this time to support a remote freeipa server

}


