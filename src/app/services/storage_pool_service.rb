#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>,
#            David Lutterkort <lutter@redhat.com>
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
# Mid-level API: Business logic around storage pools
module StoragePoolService

  include ApplicationService

  # Load the StoragePool with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@storage_pool</tt>] stores the Storage Pool with +id+
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] on StoragePool's HardwarePool
  def svc_show(id)
    lookup(id,Privilege::VIEW)
  end

  # Load the StoragePool with +id+ for editing
  #
  # === Instance variables
  # [<tt>@storage_pool</tt>] stores the Storage Pool with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on StoragePool's HardwarePool
  def svc_modify(id)
    lookup(id,Privilege::MODIFY)
  end

  # Update attributes for the StoragePool with +id+
  #
  # === Instance variables
  # [<tt>@storage_pool</tt>] stores the Storage Pool with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on StoragePool's HardwarePool
  def svc_update(id, storage_pool_hash)
    lookup(id,Privilege::MODIFY)
    authorized!(Privilege::MODIFY,@storage_pool.hardware_pool)
    StoragePool.transaction do
      @storage_pool.update_attributes!(storage_pool_hash)
      insert_refresh_task
    end
    return "Storage Pool was successfully modified."

  end

  # Refresh the StoragePool with +id+
  #
  # === Instance variables
  # [<tt>@storage_pool</tt>] stores the Storage Pool with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on StoragePool's HardwarePool
  def svc_refresh(id)
    lookup(id,Privilege::MODIFY)
    insert_refresh_task
    return "Storage pool refresh was successfully scheduled."
  end

  # Load a parent HardwarePool in preparation for creating/adding
  # a storage pool
  #
  # === Instance variables
  # [<tt>@hardware_pool</tt>] loads the HardwarePool as specified by
  #                           +hardware_pool_id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the storage pool's HardwarePool as
  #                              specified by +hardware_pool_id+
  def svc_load_hw_pool(hardware_pool_id)
    @hardware_pool = HardwarePool.find(hardware_pool_id)
    authorized!(Privilege::MODIFY,@hardware_pool)
  end

  # Load a new StoragePool for creating
  #
  # === Instance variables
  # [<tt>@storage_pool</tt>] loads a new StoragePool object into memory
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the storage pool's HardwarePool as
  #                              specified by +hardware_pool_id+
  def svc_new(hardware_pool_id, storage_type)
    new_params = { :hardware_pool_id => hardware_pool_id}
    if (storage_type == "iSCSI")
      new_params[:port] = 3260
    end
    @storage_pool = StoragePool.factory(storage_type, new_params)
    authorized!(Privilege::MODIFY,@storage_pool.hardware_pool)
  end

  # Create a new StoragePool
  #
  # === Instance variables
  # [<tt>@storage_pool</tt>] the newly-created StoragePool
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the storage pool's HardwarePool
  def svc_create(storage_type, storage_pool_hash)
    @storage_pool = StoragePool.factory(storage_type, storage_pool_hash)
    authorized!(Privilege::MODIFY,@storage_pool.hardware_pool)
    StoragePool.transaction do
      @storage_pool.save!
      insert_refresh_task
    end
    return "Storage Pool was successfully created."
  end

  # Destroys for the StoragePool with +id+
  #
  # === Instance variables
  # [<tt>@storage_pool</tt>] stores the StoragePool with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the StoragePool's HardwarePool
  def svc_destroy(id)
    lookup(id, Privilege::MODIFY)
    unless @storage_pool.movable?
      raise ActionError.new("Cannot delete storage with associated vms")
    end
    @storage_pool.destroy
    return "Storage Pool was successfully deleted."
  end

  private
  def lookup(id, priv)
    @storage_pool = StoragePool.find(id)
    authorized!(priv,@storage_pool.hardware_pool)
  end

  def insert_refresh_task
    @task = StorageTask.new({ :user        => @user,
                              :task_target => @storage_pool,
                              :action      => StorageTask::ACTION_REFRESH_POOL,
                              :state       => Task::STATE_QUEUED})
    @task.save!
  end


end
