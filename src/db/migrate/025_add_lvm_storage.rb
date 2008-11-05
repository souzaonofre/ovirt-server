#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>
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

class AddLvmStorage < ActiveRecord::Migration
  def self.up
    #LVM pool does not use ip_addr

    # VG Name
    add_column :storage_pools, :vg_name, :string

    # LV name
    add_column :storage_volumes, :lv_name, :string
    # LV capacity==existing size attr

    # LV <target><permissions>
    # FIXME: do we want to make these user-determined, or should
    # these be defined by the model itself?
    add_column :storage_volumes, :lv_owner_perms, :string
    add_column :storage_volumes, :lv_group_perms, :string
    add_column :storage_volumes, :lv_mode_perms, :string

    # VG pool ID
    add_column :storage_volumes, :lvm_pool_id, :integer
    execute "alter table storage_volumes add constraint fk_storage_volumes_lvm_pools
             foreign key (lvm_pool_id) references storage_pools(id)"

    # use polymorphic tasks association
    add_column :tasks, :task_target_id, :integer
    add_column :tasks, :task_target_type, :string
    begin
      Task.transaction do
        HostTask.find(:all).each do |task|
          task.task_target_type = 'Host'
          task.task_target_id = task.host_id
          task.save!
        end
        StorageTask.find(:all).each do |task|
          task.task_target_type = 'StoragePool'
          task.task_target_id = task.storage_pool_id
          task.save!
        end
        VmTask.find(:all).each do |task|
          task.task_target_type = 'Vm'
          task.task_target_id = task.vm_id
          task.save!
        end
      end
      remove_column :tasks, :vm_id
      remove_column :tasks, :storage_pool_id
      remove_column :tasks, :host_id
    rescue
      puts "could not update tasks..."
    end

  end

  def self.down
    remove_column :storage_pools, :vg_name

    remove_column :storage_volumes, :lv_name
    remove_column :storage_volumes, :lv_owner_perms
    remove_column :storage_volumes, :lv_group_perms
    remove_column :storage_volumes, :lv_mode_perms
    remove_column :storage_volumes, :lvm_pool_id

    add_column :tasks, :vm_id, :integer
    add_column :tasks, :storage_pool_id, :integer
    add_column :tasks, :host_id, :integer
    begin
      Task.transaction do
        HostTask.find(:all).each do |task|
          task.host_id = task.task_target_id
          task.save!
        end
        StorageTask.find(:all).each do |task|
          task.storage_pool_id = task.task_target_id
          task.save!
        end
        VmTask.find(:all).each do |task|
          task.vm_id = task.task_target_id
          task.save!
        end
      end
      remove_column :tasks, :task_target_id
      remove_column :tasks, :task_target_type
    rescue
      puts "could not update tasks..."
    end
  end
end
