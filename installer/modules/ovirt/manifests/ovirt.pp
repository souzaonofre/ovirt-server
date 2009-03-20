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

class ovirt::setup {

	file_replacement{"ovirt_httpd_config_change_guest_net":
	        file => "/etc/httpd/conf.d/ovirt-server.conf",
	        pattern => "GuestNetIpAddress",
	        replacement => "$guest_httpd_ipaddr",
		require => Package[ovirt-server]
        }

	file_replacement{"ovirt_httpd_config_change_admin_net":
	        file => "/etc/httpd/conf.d/ovirt-server.conf",
	        pattern => "AdminNetIpAddress",
	        replacement => "$admin_ipaddr",
		require => Package[ovirt-server]
        }

	file_replacement{"ovirt_httpd_config_change_server_fqdn":
	        file => "/etc/httpd/conf.d/ovirt-server.conf",
	        pattern => "AdminNodeFQDN",
	        replacement => "$ovirt_host",
		require => Package[ovirt-server]
        }

        package {"ovirt-server":
		ensure => installed,
		require => Single_exec[set_pw_expiration]
	}

	package {"httpd":
	        ensure => installed;
	}

	package {"rubygem-rake":
		ensure => installed;
	}

	package {"qpidd":
	        ensure => installed;
	}

	package {"collectd":
		ensure => installed;
	}

	package {"collectd-rrdtool":
		ensure => installed;
	}

	package {"libvirt":
	        ensure => installed;
	}

	package {"ruby-qpid":
	        ensure => installed;
	}

	package {"ntp":
	        ensure => installed;
	}

        package {"livecd-tools":
                ensure => installed;
        }
	file {"/etc/collectd.conf":
		source => "puppet:///ovirt/collectd.conf",
		notify => Service[collectd],
        require => Package["collectd-rrdtool"]
	}

	file {"/etc/qpidd.conf":
		source => "puppet:///ovirt/qpidd.conf",
		notify => Service[qpidd]
	}

        file {"/etc/sasl2/qpidd.conf":
                source => "puppet:///ovirt/sasl2_qpidd.conf",
                notify => Service["qpidd"]
        }

	single_exec { "db_migrate" :
		cwd => "/usr/share/ovirt-server/",
		command => "/usr/bin/rake db:migrate",
		require => [File["/usr/share/ovirt-server/log"],Package[ovirt-server],Package[rubygem-rake],Postgres_execute_command["ovirt_db_grant_permissions"]],
        environment => "RAILS_ENV=production"
	}

	file { "/usr/share/ovirt-server/log" :
		ensure => directory,
		require => Package[ovirt-server]
	}

        single_exec { "create_ovirtadmin_acct" :
		command => "/usr/share/ovirt-server/script/grant_admin_privileges ovirtadmin",
                require => [Single_Exec[db_migrate],Single_exec[set_ldap_hostname],Single_exec[set_ldap_dn]]
	}

        single_exec { "set_ldap_hostname" :
                command => "/bin/sed -i -e 's/management.priv.ovirt.org/$ipa_host/' /usr/share/ovirt-server/config/ldap.yml",
                require => Package[ovirt-server]
        }

        single_exec { "set_ldap_dn" :
                command => "/bin/sed -i -e 's/dc=priv,dc=ovirt,dc=org/$short_ldap_dn/' /usr/share/ovirt-server/config/ldap.yml",
                require => Package[ovirt-server]
        }

	single_exec { "add_host" :
		command => "/usr/bin/ovirt-add-host $ipa_host /usr/share/ovirt-server/ovirt.keytab",
		require => Package[ovirt-server],
		notify => Service[qpidd]
	}

	service {"httpd" :
                enable => true,
                require => Package[httpd],
                ensure => running
        }

	service {"libvirt" :
                require => Package[libvirt]
        }

        service {"ovirt-host-browser" :
                enable => true,
		require => [Package[ovirt-server],Single_Exec[db_migrate]],
                ensure => running
        }

        service {"ovirt-host-collect" :
                enable => true,
		require => [Package[ovirt-server],Single_Exec[db_migrate]],
                ensure => running
        }

        service {"ovirt-mongrel-rails" :
                enable => true,
		require => [Package[ovirt-server],Single_Exec[db_migrate]],
                ensure => running,
		notify => Service[httpd]
        }

	service {"ovirt-taskomatic" :
                enable => true,
		require => [Package[ovirt-server],Single_Exec[db_migrate]],
                ensure => running
        }

	service {"ovirt-db-omatic" :
                enable => true,
		require => [Package[ovirt-server],Single_Exec[db_migrate]],
                ensure => running
        }

        service {"qpidd" :
                enable => true,
                ensure => running,
                require => Package[qpidd]
                }

        service {"collectd" :
                enable => true,
                ensure => running,
                require => Package[collectd]
                }

	service {"ntpd" :
                enable => true,
                ensure => running,
		require => Package[ntp]
                }

    service {"ace" :
                enable => false
    }

        firewall_rule{"http": destination_port => "80"}
        firewall_rule {"https": destination_port => '443'}
        firewall_rule {"host-browser": destination_port => '12120'}
        firewall_rule {"qpidd": destination_port => '5672'}
        firewall_rule {"collectd": destination_port => '25826', protocol => 'udp'}
        firewall_rule {"ntpd": destination_port => '123', protocol => 'udp'}

    exec{"refresh-iptables":
                command => "/usr/local/bin/iptables-update.sh",
                require => [Service["ovirt-mongrel-rails"],Service["ovirt-taskomatic"],Service["ovirt-db-omatic"]]
    }
    exec{"iptables-save":
                command => "/sbin/iptables-save > /etc/sysconfig/iptables",
                require => Exec["refresh-iptables"]
    }
}
