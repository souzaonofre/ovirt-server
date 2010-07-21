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
      entry  = "ifcfg=none|#{bonding.interface_name}"
      entry += "|BONDING_OPTS=\"mode=#{bonding.bonding_type.mode} miimon=100\""
      entry += "|BRIDGE=br#{bonding.interface_name}"
      entry += "|ONBOOT=yes"
      result.puts entry

      if bonding.networking?
        add_bridge(result,"none",bonding.interface_name,
                   bonding.boot_protocol, bonding.ip_address,
                   bonding.netmask, bonding.broadcast,
                   bonding.gateway)
      end

      bonding.nics.each do |nic|
        iface_name = macs[nic.mac]
        if iface_name
          add_slave(result, nic.mac, iface_name, bonding.interface_name)
        end
      end
    end

    host.nics.each do |nic|
      if nic.networking? && !nic.bonded?
        iface_name = macs[nic.mac]
        if iface_name
          add_bridge(result, nic.mac, iface_name,
                     nic.boot_protocol, nic.ip_address,
                     nic.netmask, nic.broadcast,
                     nic.gateway)
          add_nic(result, nic.mac, iface_name)
	
	  # process the vlan tagging

          nic.network.usages.map do |usage|
	    usage.networks.map do |net|
	      if net.type == "Vlan"
	        eth_vlan_name = "#{nic.interface_name}.#{net.number}" 
                 add_bridge(result, 'none', eth_vlan_name,
                     nic.boot_protocol, nic.ip_address,
                     nic.netmask, nic.broadcast,
                     nic.gateway)
                 add_vlan(result, eth_vlan_name)
	      end
	    end # end of : usage.networks.map do |net|
	  end # end of : nic.network.usages.map do |usage|
        end
      end
    end

    result.string
  end

  private

  def self.add_bridge(result, mac, iface_name, bootproto,
                      ipaddress, netmask, broadcast, gateway)
    entry = "ifcfg=#{mac}|br#{iface_name}|BOOTPROTO=#{bootproto}"
    if bootproto == "static"
      entry += "|IPADDR=#{ipaddress}|NETMASK=#{netmask}|BROADCAST=#{broadcast}|GATEWAY=#{gateway}"
    end
    entry += "|TYPE=Bridge|PEERDNS=no|ONBOOT=yes"
    result.puts entry
  end

  def self.add_nic(result, mac, iface_name)
    result.puts "ifcfg=#{mac}|#{iface_name}|BRIDGE=br#{iface_name}|ONBOOT=yes"
  end

  def self.add_slave(result, mac, iface_name, master)
    result.puts "ifcfg=#{mac}|#{iface_name}|MASTER=#{master}|SLAVE=yes|ONBOOT=yes"
  end

  def self.add_vlan(result, iface_name)
    result.puts "ifcfg=none|#{iface_name}|BRIDGE=br#{iface_name}|ONBOOT=yes|VLAN=yes"
  end

end
