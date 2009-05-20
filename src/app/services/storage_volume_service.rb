#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>,
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
# Mid-level API: Business logic around storage volumes
module StorageVolumeService

  include ApplicationService

  # Load the StorageVolume with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@storage_volume</tt>] stores the Storage Volume with +id+
  # [<tt>@storage_pool</tt>] stores the Storage Volume's Storage Pool
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] on StorageVolume's HardwarePool
  def svc_show(id)
    lookup(id,Privilege::VIEW)
  end

  # Load the StorageVolume with +id+ for editing
  #
  # === Instance variables
  # [<tt>@storage_volume</tt>] stores the Storage Volume with +id+
  # [<tt>@storage_pool</tt>] stores the Storage Volume's Storage Pool
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on StorageVolume's HardwarePool
  def svc_modify(id)
    lookup(id,Privilege::MODIFY)
  end

  # Load a new StorageVolume for creating
  #
  # === Instance variables
  # [<tt>@storage_volume</tt>] loads a new StorageVolume object into memory
  # [<tt>@storage_pool</tt>] Storage pool containing <tt>@storage_volume</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the storage volume's HardwarePool
  def svc_new(storage_pool_id)
    @storage_pool = StoragePool.find(storage_pool_id)
    unless @storage_pool.user_subdividable
      raise ActionError.new("Unsupported action for " +
                            "#{@storage_pool.get_type_label} volumes.")
    end
    authorized!(Privilege::MODIFY,@storage_pool.hardware_pool)
    @storage_volume = StorageVolume.factory(@storage_pool.get_type_label,
                                            { :storage_pool_id =>
                                              @storage_pool.id})
  end

  # Load a new LvmStorageVolume for creating
  #
  # === Instance variables
  # [<tt>@storage_volume</tt>] loads a new StorageVolume object into memory
  # [<tt>@storage_pool</tt>] Storage pool containing <tt>@storage_volume</tt>
  # [<tt>@source_volume</tt>] Storage volume containing the LVM
  #                           <tt>@storage_pool</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the storage volume's HardwarePool
  def svc_new_lv(source_volume_id)
    @source_volume = StorageVolume.find(source_volume_id)
    unless @source_volume.supports_lvm_subdivision
      raise ActionError.new("LVM is not supported for this storage volume")
    end
    authorized!(Privilege::MODIFY,@source_volume.storage_pool.hardware_pool)

    @storage_pool = @source_volume.lvm_storage_pool
    unless @storage_pool
      # FIXME: what should we do about VG/LV names?
      # for now auto-create VG name as ovirt_vg_#{@source_volume.id}
      new_params = { :vg_name => "ovirt_vg_#{@source_volume.id}",
        :hardware_pool_id => @source_volume.storage_pool.hardware_pool_id}
      @storage_pool = StoragePool.factory(StoragePool::LVM, new_params)
      @storage_pool.source_volumes << @source_volume
      @storage_pool.save!
    end
    @storage_volume = StorageVolume.factory(@storage_pool.get_type_label,
                                            { :storage_pool_id =>
                                              @storage_pool.id})
  end

  # Create a new StorageVolume
  #
  # === Instance variables
  # [<tt>@storage_volume</tt>] the newly-created StorageVolume
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the storage volume's HardwarePool
  def svc_create(storage_type, storage_volume_hash)
    @storage_volume = StorageVolume.factory(storage_type, storage_volume_hash)
    authorized!(Privilege::MODIFY,@storage_volume.storage_pool.hardware_pool)
    StorageVolume.transaction do
      @storage_volume.save!
      @task = StorageVolumeTask.new({ :user        => @user,
                                      :task_target => @storage_volume,
                      :action      => StorageVolumeTask::ACTION_CREATE_VOLUME})
        @task.save!
    end
    return "Storage Volume was successfully created."
  end

  # Queues StorageVolume with +id+ for deletion
  #
  # === Instance variables
  # [<tt>@storage_volume</tt>] stores the Storage Volume with +id+
  # [<tt>@storage_pool</tt>] stores the Storage Volume's Storage Pool
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on StorageVolume's HardwarePool
  def svc_destroy(id)
    lookup(id, Privilege::MODIFY)
    unless @storage_pool.user_subdividable
      raise ActionError.new("Unsupported action for " +
                            "#{@storage_volume.get_type_label} volumes.")
    end
    unless @storage_volume.vms.empty?
      vms = @storage_volume.vms.collect {|vm| vm.description}.join(", ")
      raise ActionError.new("Cannot delete storage assigned to VMs (#{vms})")
    end
    name = @storage_volume.display_name
    StorageVolume.transaction do
      @storage_volume.state=StorageVolume::STATE_PENDING_DELETION
      @storage_volume.save!
      @task = StorageVolumeTask.new({ :user        => @user,
                                      :task_target => @storage_volume,
                       :action      => StorageVolumeTask::ACTION_DELETE_VOLUME})
      @task.save!
    end
    return "Storage Volume #{name} deletion was successfully queued."
  end

  private
  def lookup(id, priv)
    @storage_volume = StorageVolume.find(id)
    @storage_pool = @storage_volume.storage_pool
    authorized!(priv,@storage_pool.hardware_pool)
  end

end
