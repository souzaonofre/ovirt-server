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
     add_foreign_key :nics, :vms, :name => 'fk_nics_vm_id'
     change_column :nics, :host_id, :integer, :null => true

     # change physical_network_id column in nic table to network_id
     remove_foreign_key :nics, :name => 'fk_nic_networks'
     rename_column :nics, :physical_network_id, :network_id
     add_foreign_key :nics, :networks, :name => 'fk_nic_networks'

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
     remove_foreign_key :vms, :name => 'fk_vm_network_id'
     remove_column :vms, :network_id
     remove_column :vms, :vnic_mac_addr

    begin
     # add to the db some validations
     #   host_id is set xor vm_id  is set
     execute 'alter table nics add constraint host_xor_vm
              check (host_id IS NOT NULL and vm_id IS NULL or
                     vm_id IS NOT NULL and host_id IS NULL)'
     #   network_id is set if vm_id is
     execute 'alter table nics add constraint vm_nic_has_network
              check (vm_id IS NULL or network_id IS NOT NULL)'
     #   vm_id is set if network is vlan (TBD)
    rescue ActiveRecord::StatementInvalid => e
      # this kind of validation cannot be made on sqlite
    rescue Exception => e
      throw e
    end
  end

  def self.down
    # drop constraints added to nics table
    begin
     execute 'alter table nics drop constraint host_xor_vm'
     execute 'alter table nics drop constraint vm_nic_has_network'
    rescue ActiveRecord::StatementInvalid => e
      # this kind of validation cannot be made on sqlite
    rescue Exception => e
      throw e
    end

    # add network_id, vnic_mac_addr column back to vm table
    add_column :vms, :network_id, :integer
    add_column :vms, :vnic_mac_addr, :string
    add_foreign_key :vms, :networks, :name => 'fk_vm_network_id'

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
    change_column :nics, :host_id, :integer, :null => false

    # change nic::network_id back to nic::physical_network_id
    remove_foreign_key :nics, :name => 'fk_nic_networks'
    rename_column :nics, :network_id, :physical_network_id
    add_foreign_key :nics, :networks, :column => 'physical_network_id',
                                      :name => 'fk_nic_networks'
  end
end
