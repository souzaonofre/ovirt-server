#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

require File.dirname(__FILE__) + '/../test_helper'
require 'test/unit'
require 'managed_node_configuration'

# Performs unit tests on the +ManagedNodeConfiguration+ class.
#
class ManagedNodeConfigurationTest < Test::Unit::TestCase
  fixtures :bonding_types
  fixtures :bondings
  fixtures :bondings_nics
  fixtures :boot_types
  fixtures :hosts
  fixtures :nics

  def setup
    @host_with_dhcp_card = hosts(:fileserver_managed_node)
    @host_with_ip_address = hosts(:ldapserver_managed_node)
    @host_with_multiple_nics = hosts(:buildserver_managed_node)
    @host_with_bondings = hosts(:mailservers_managed_node)
  end

  # Ensures that network interfaces uses DHCP when no IP address is specified.
  #
  def test_generate_with_no_ip_address
    nic = @host_with_dhcp_card.nics.first

    expected = <<-HERE
#!/bin/bash
# THIS FILE IS GENERATED!
cat <<\EOF > /var/tmp/node-augtool
rm /files/etc/sysconfig/network-scripts/ifcfg-eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/DEVICE eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BOOTPROTO #{nic.boot_type.proto}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BRIDGE ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/ONBOOT yes
rm /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/DEVICE ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/BOOTPROTO #{nic.boot_type.proto}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/TYPE bridge
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/PEERNTP yes
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/DELAY 0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/ONBOOT yes
save
EOF
    HERE

    result = ManagedNodeConfiguration.generate(
      @host_with_dhcp_card,
      {"#{nic.mac}" => 'eth0'}
    )

    assert_equal expected, result
  end

  # Ensures that network interfaces use the IP address when it's provided.
  #
  def test_generate_with_ip_address_and_bridge
    nic = @host_with_ip_address.nics.first

    expected = <<-HERE
#!/bin/bash
# THIS FILE IS GENERATED!
cat <<\EOF > /var/tmp/node-augtool
rm /files/etc/sysconfig/network-scripts/ifcfg-eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/DEVICE eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BOOTPROTO #{nic.boot_type.proto}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/IPADDR #{nic.ip_addr}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/NETMASK #{nic.netmask}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BROADCAST #{nic.broadcast}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BRIDGE ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/ONBOOT yes
rm /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/DEVICE ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/BOOTPROTO #{nic.boot_type.proto}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/IPADDR #{nic.ip_addr}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/NETMASK #{nic.netmask}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/BROADCAST #{nic.broadcast}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/TYPE bridge
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/PEERNTP yes
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/DELAY 0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/ONBOOT yes
save
EOF
    HERE

    result = ManagedNodeConfiguration.generate(
      @host_with_ip_address,
      {"#{nic.mac}" => 'eth0'}
    )

    assert_equal expected, result
  end

  # Ensures that more than one NIC is successfully processed.
  #
  def test_generate_with_multiple_nics
    nic1 = @host_with_multiple_nics.nics[0]
    nic2 = @host_with_multiple_nics.nics[1]

    expected = <<-HERE
#!/bin/bash
# THIS FILE IS GENERATED!
cat <<\EOF > /var/tmp/node-augtool
rm /files/etc/sysconfig/network-scripts/ifcfg-eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/DEVICE eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BOOTPROTO #{nic1.boot_type.proto}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/IPADDR #{nic1.ip_addr}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/NETMASK #{nic1.netmask}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BROADCAST #{nic1.broadcast}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/BRIDGE ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/ONBOOT yes
rm /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/DEVICE ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/BOOTPROTO #{nic1.boot_type.proto}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/IPADDR #{nic1.ip_addr}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/NETMASK #{nic1.netmask}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/BROADCAST #{nic1.broadcast}
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/TYPE bridge
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/PEERNTP yes
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/DELAY 0
set /files/etc/sysconfig/network-scripts/ifcfg-ovirtbr0/ONBOOT yes
rm /files/etc/sysconfig/network-scripts/ifcfg-eth1
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/DEVICE eth1
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/BOOTPROTO #{nic2.boot_type.proto}
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/BRIDGE ovirtbr0
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/ONBOOT yes
save
EOF
    HERE

    result = ManagedNodeConfiguration.generate(
      @host_with_multiple_nics,
      {
        "#{nic1.mac}" => 'eth0',
        "#{nic2.mac}" => 'eth1'
      })

    assert_equal expected, result
  end

  # Ensures that the bonding portion is created if the host has a bonded
  # interface defined.
  #
  def test_generate_with_bonding
    bonding = @host_with_bondings.bondings.first

    nic1 = bonding.nics[0]
    nic2 = bonding.nics[1]

    expected = <<-HERE
#!/bin/bash
# THIS FILE IS GENERATED!
cat <<\EOF > /var/tmp/pre-config-script
#!/bin/bash
# THIS FILE IS GENERATED!
/sbin/modprobe bonding mode=#{bonding.bonding_type.mode}
EOF
cat <<\EOF > /var/tmp/node-augtool
rm /files/etc/sysconfig/network-scripts/ifcfg-#{bonding.interface_name}
set /files/etc/sysconfig/network-scripts/ifcfg-#{bonding.interface_name}/DEVICE #{bonding.interface_name}
set /files/etc/sysconfig/network-scripts/ifcfg-#{bonding.interface_name}/IPADDR 172.31.0.15
set /files/etc/sysconfig/network-scripts/ifcfg-#{bonding.interface_name}/ONBOOT yes
rm /files/etc/sysconfig/network-scripts/ifcfg-eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/DEVICE eth0
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/MASTER #{bonding.interface_name}
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/SLAVE yes
set /files/etc/sysconfig/network-scripts/ifcfg-eth0/ONBOOT yes
rm /files/etc/sysconfig/network-scripts/ifcfg-eth1
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/DEVICE eth1
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/MASTER #{bonding.interface_name}
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/SLAVE yes
set /files/etc/sysconfig/network-scripts/ifcfg-eth1/ONBOOT yes
save
EOF
HERE

    result = ManagedNodeConfiguration.generate(
      @host_with_bondings,
      {
        "#{nic1.mac}" => 'eth0',
        "#{nic2.mac}" => 'eth1'
      })

    assert_equal expected, result
  end

end
