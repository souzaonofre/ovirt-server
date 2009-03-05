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

class appliance::bundled {

$nfs_changes = [
    "set /files/etc/sysconfig/nfs/MOUNTD_PORT 892"
]

augeas {"nfs_config":
    changes => $nfs_changes,
    notify => Service["nfs"]
}

$nfslock_changes = [
    "set /files/etc/sysconfig/nfs/LOCKD_TCPPORT 32803",
    "set /files/etc/sysconfig/nfs/LOCKD_UDPPORT 32769",
    "set /files/etc/sysconfig/nfs/STATD_PORT 662"
]

augeas {"nfslock_config":
    changes => $nfslock_changes,
    notify => Service["nfslock"]
}

firewall_rule {"tgtd": destination_port => '3260'}
firewall_rule {"nfsd": destination_port => '2049'}
firewall_rule {"rpcbind": destination_port => '111'}
firewall_rule {"rpcbind-udp": destination_port => '111', protocol => 'udp'}
firewall_rule {"rpc.mountd": destination_port => '892'}
firewall_rule {"rpc.mountd-udp": destination_port => '892', protocol => 'udp'}
firewall_rule {"rpc.statd": destination_port => '662'}
firewall_rule {"rpc.statd-udp": destination_port => '662', protocol => 'udp'}

service {"nfs":
    ensure => "running",
    enable => true,
    require => Service["network"]
}

service {"nfslock":
    ensure => "running",
    enable => true
}

service {"network":
    ensure => "running",
    enable => true
}

file{"/mnt/data/ovirtiscsi":
    ensure => directory
}

file{"/ovirtiscsi":
    ensure => directory
}

file{"/ovirtnfs":
    ensure => directory
}

file{"/mnt/data/ovirtnfs":
    ensure => directory
}

mount{"/ovirtiscsi":
    atboot => true,
    ensure => mounted,
    fstype => bind,
    options => bind,
    device => "/mnt/data/ovirtiscsi",
    require => [File["/mnt/data/ovirtiscsi"],File["/ovirtiscsi"]]
}

mount{"/ovirtnfs":
    atboot => true,
    ensure => mounted,
    fstype => bind,
    options => bind,
    device => "/mnt/data/ovirtnfs",
    require => [File["/mnt/data/ovirtnfs"],File["/ovirtnfs"]]
}

file {"/usr/sbin/ovirt-appliance-setup":
    source => "puppet:///ovirt/ovirt-appliance-setup",
    mode => 755
}

single_exec{"ovirtnfs_export":
    command => '/bin/echo "/ovirtnfs 192.168.50.0/24(rw,no_root_squash)" >> /etc/exports',
    notify => Service[nfs]
}

file{"/mnt/data/cobblernfs":
    ensure => directory
}

file{"/cobblernfs":
    ensure => directory
}

mount{"/cobblernfs":
    atboot => true,
    ensure => mounted,
    fstype => bind,
    options => bind,
    device => "/mnt/data/ovirtnfs",
    require => [File["/mnt/data/ovirtnfs"],File["/cobblernfs"]]
}

single_exec{"cobbler_nfs_export":
    command => '/bin/echo "/cobblernfs 192.168.50.0/24(rw,no_root_squash)" >> /etc/exports',
    notify => Service[nfs],
    require => Mount["/cobblernfs"]
}


file {"/etc/init.d/ovirt-storage":
	source => "puppet:///ovirt/ovirt-storage",
	mode => 755
}

single_exec{"ovirt-appliance-setup":
    command => "/usr/sbin/ovirt-appliance-setup",
    require => File["/usr/sbin/ovirt-appliance-setup"]
    }

service {"ovirt-storage":
    ensure => "running",
    enable => true,
    require => [File["/etc/init.d/ovirt-storage"],Single_exec["ovirt-appliance-setup"]]
}

}
