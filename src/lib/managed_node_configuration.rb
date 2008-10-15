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

class ManagedNodeConfiguration
  NIC_ENTRY_PREFIX='/files/etc/sysconfig/network-scripts'

  def self.generate(host, macs)
    result = StringIO.new

    result.puts "#!/bin/bash"
    result.puts "# THIS FILE IS GENERATED!"

    # first process any bondings that're defined
    unless host.bondings.empty?
      result.puts "cat <<\EOF > /var/tmp/pre-config-script"
      result.puts "#!/bin/bash"
      result.puts "# THIS FILE IS GENERATED!"

      host.bondings.each do |bonding|
        result.puts "/sbin/modprobe bonding mode=#{bonding.bonding_type.mode}"
      end

      result.puts "EOF"
    end

    # now process the network interfaces  and bondings
    result.puts "cat <<\EOF > /var/tmp/node-augtool"

    host.bondings.each do |bonding|
      result.puts "rm #{NIC_ENTRY_PREFIX}/ifcfg-#{bonding.interface_name}"
      result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{bonding.interface_name}/DEVICE #{bonding.interface_name}"
      result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{bonding.interface_name}/IPADDR #{bonding.ip_addr}" if bonding.ip_addr
      result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{bonding.interface_name}/ONBOOT yes"

      bonding.nics.each do |nic|
        process_nic result, nic, macs, bonding
      end
    end

    has_bridge = false
    host.nics.each do |nic|
      # only process this nic if it doesn't have a bonding
      # TODO remove the hack to force a bridge into the picture
      if nic.bonding.empty?
        process_nic result, nic, macs, nil, false, true

	# TODO remove this when bridges are properly supported
	unless has_bridge
	  macs[nic.mac] = "ovirtbr0"
	  process_nic result, nic, macs, nil, true, false
	  has_bridge = true
	end
      end
    end

    result.puts "save"
    result.puts "EOF"

    result.string
  end

  private

  def self.process_nic(result, nic, macs, bonding = nil, is_bridge = false, bridged = true)
    iface_name = macs[nic.mac]

    if iface_name
      result.puts "rm #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}"
      result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/DEVICE #{iface_name}"

      if bonding
        result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/MASTER #{bonding.interface_name}"
        result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/SLAVE yes"
      else
        result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/BOOTPROTO #{nic.boot_type.proto}"

        if nic.boot_type.proto == 'static'
          result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/IPADDR #{nic.ip_addr}"
          result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/NETMASK #{nic.netmask}"
          result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/BROADCAST #{nic.broadcast}"
        end

	if bridged
	  result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/BRIDGE ovirtbr0"
	elsif is_bridge
	  result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/TYPE bridge"
	  result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/PEERNTP yes"
	  result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/DELAY 0"
	end
      end

      result.puts "set #{NIC_ENTRY_PREFIX}/ifcfg-#{iface_name}/ONBOOT yes"
    end
  end
end
