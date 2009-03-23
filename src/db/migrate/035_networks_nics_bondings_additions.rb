# Copyright (C) 2008 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
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

# adds
#  'interface_name' column to the nics table
#  'network_id' to vms table
#  host_id / network_id constraints to nics / bondings
#
class NetworksNicsBondingsAdditions < ActiveRecord::Migration
  def self.up
    add_column :nics, :interface_name, :string
    add_column :vms,  :network_id, :integer

    dhcp_boot_type = BootType.find(:first, :conditions=>"proto='dhcp'")
    usages = Usage.find(:all)

    # drop all physical_network_ids and vlan_ids
    execute 'update nics set physical_network_id = NULL'
    execute 'update bondings set vlan_id = NULL'

    execute "alter table nics add constraint
             host_physical_network_unique unique
             (host_id, physical_network_id)"

    execute "alter table bondings add constraint
             host_vlan_unique unique
             (host_id, vlan_id)"

    execute "alter table vms add constraint
             fk_vm_network_id
             foreign key (network_id) references
             networks(id)"
  end

  def self.down
    remove_column :nics, :interface_name
    remove_column :vms,  :network_id
  end
end

