# Copyright (C) 2009 Red Hat, Inc.
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

class AssociateVmsWithNics < ActiveRecord::Migration

  def self.up
     # assocate nics w/ vms
     add_column :nics, :vm_id, :integer
     execute "alter table nics add constraint
              fk_nics_vm_id
              foreign key (vm_id) references
              vms(id)"
     execute "alter table nics alter column host_id DROP NOT NULL"

     # change physical_network_id column in nic table to network_id
     execute 'alter table nics drop constraint fk_nic_networks'
     execute 'alter table nics rename column physical_network_id to network_id'
     execute 'alter table nics add constraint fk_nic_networks
              foreign key (network_id) references networks(id)'


     # create a nic for each vm / network
     Vm.find(:all, :conditions => "network_id IS NOT NULL").each{ |vm|
       nic = Nic.new(:mac => vm.vnic_mac_addr,
                     :network_id => vm.network_id,
                     :vm_id => vm.id,
                     :bandwidth => 0)
       nic.vm = vm
       vm.nics.push nic

       vm.save!
       nic.save!
     }

     # removes 1toM networks/vms relationship
     # remove network_id column from vms table
     # remove vnic_mac_addr column from vms table
     execute 'alter table vms drop constraint fk_vm_network_id'
     remove_column :vms, :network_id
     remove_column :vms, :vnic_mac_addr

     # add to the db some validations
     #   host_id is set xor vm_id  is set
     execute 'alter table nics add constraint host_xor_vm
              check (host_id IS NOT NULL and vm_id IS NULL or
                     vm_id IS NOT NULL and host_id IS NULL)'
     #   network_id is set if vm_id is
     execute 'alter table nics add constraint vm_nic_has_network
              check (vm_id IS NULL or network_id IS NOT NULL)'
     #   vm_id is set if network is vlan (TBD)
  end

  def self.down
    # drop constraints added to nics table
    execute 'alter table nics drop constraint host_xor_vm'
    execute 'alter table nics drop constraint vm_nic_has_network'

    # add network_id, vnic_mac_addr column back to vm table
    add_column :vms, :network_id, :integer
    add_column :vms, :vnic_mac_addr, :string
    execute 'alter table vms add constraint fk_vm_network_id
             foreign key (network_id) references networks(id)'

    # copy network id over
    # NOTE since we're going from a MtoM relationship to a 1toM
    #  we're just gonna associate the last network found
    #  w/ the vm, so this operation is lossy
    Nic.find(:all, :conditions => 'vm_id IS NOT NULL').each{ |nic|
       vm = Vm.find(nic.vm_id)
       vm.vnic_mac_addr = nic.mac
       vm.network_id = nic.network_id
       vm.save!
       nic.destroy
    }

    # unassociate nics / vms
    remove_column :nics, :vm_id
    execute "alter table nics alter column host_id SET NOT NULL"

    # change nic::network_id back to nic::physical_network_id
    execute 'alter table nics drop constraint fk_nic_networks'
    execute 'alter table nics rename column network_id to physical_network_id'
    execute 'alter table nics add constraint fk_nic_networks
              foreign key (physical_network_id) references networks(id)'
  end
end
