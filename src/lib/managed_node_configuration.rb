#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA  02110-1301, USA.  A copy of the GNU General
# Public License is also available at http://www.gnu.org/copyleft/gpl.html.

# +ManagedNodeConfiguration+ takes in the description for a managed node and,
# from that, generates the configuration file that is consumed the next time the
# managed node starts up.
#

require 'stringio'

# +ManagedNodeConfiguration+ generates a configuration file for an oVirt node
# based on information about the hardware submitted by the node and the
# configuration details held in the database.
#
# The configuration is returned as a series of encoded lines.
#
# For a kernel module, the formation of the line is as follows:
#
# bonding=[bonding alias]
#
# An example would be for loading the +bonding+ kernel module to setup a bonded
# interface for load balancing. In this example, the bonded interface would be
# named +failover0+ on the node:
#
# bonding=failover0
#
# For a network interface (including a bonded interface) an example would be:
#
# ifcfg=00:11:22:33:44|eth0|BOOTPROTO=dhcp|bridge=breth0|ONBOOT=yes
#
# In this line, the network interface +eth0+ has a hardware MAC address of
# +00:11:22:33:44+. It will use DHCP for retrieving it's IP address details,
# and will use the +breth0+ interface as a bridge.
#
class ManagedNodeConfiguration
  NIC_ENTRY_PREFIX='/files/etc/sysconfig/network-scripts'

  def self.generate(host, macs)
    result = StringIO.new

    result.puts "# THIS FILE IS GENERATED!"

    # first process any bondings that're defined
    unless host.bondings.empty?
      host.bondings.each do |bonding|
        result.puts "bonding=#{bonding.interface_name}"
      end
    end

    # now process the network interfaces  and bondings

    host.bondings.each do |bonding|
      entry = "ifcfg=none|#{bonding.interface_name}|BONDING_OPTS=\"mode=#{bonding.bonding_type.mode} miimon=100\""

      if bonding.ip_addresses.empty?
        entry += "|BOOTPROTO=dhcp"
      else
        ip = bonding.ip_addresses[0]
        entry += "|BOOTPROTO=static|IPADDR=#{ip.address}|NETMASK=#{ip.netmask}|BROADCAST=#{ip.broadcast}"
      end

      result.puts "#{entry}|ONBOOT=yes"

      bonding.nics.each do |nic|
        process_nic result, nic, macs, bonding
      end
    end

    has_bridge = false
    host.nics.each do |nic|
      # only process this nic if it doesn't have a bonding
      # TODO remove the hack to force a bridge into the picture
      if nic.bondings.empty?
        process_nic result, nic, macs, nil, false, true

	# TODO remove this when bridges are properly supported
	unless has_bridge
	  macs[nic.mac] = "breth0"
	  process_nic result, nic, macs, nil, true, false
	  has_bridge = true
	end
      end
    end

    result.string
  end

  private

  def self.process_nic(result, nic, macs, bonding = nil, is_bridge = false, bridged = true)
    iface_name = macs[nic.mac]

    if iface_name
      entry = "ifcfg=#{nic.mac}|#{iface_name}"

      if bonding
        entry += "|MASTER=#{bonding.interface_name}|SLAVE=yes"
      else
        entry += "|BOOTPROTO=#{nic.physical_network.boot_type.proto}"
        if nic.physical_network.boot_type.proto == 'static'
          ip = nic.ip_addresses[0]
          entry += "|IPADDR=#{ip.address}|NETMASK=#{ip.netmask}|BROADCAST=#{ip.broadcast}"
        end
        entry += "|BRIDGE=#{nic.bridge}" if nic.bridge && !is_bridge
        entry += "|BRIDGE=breth0" if !nic.bridge && !is_bridge
        entry += "|TYPE=bridge" if is_bridge
      end
      entry += "|ONBOOT=yes"
    end

    result.puts entry if defined? entry
  end
end
