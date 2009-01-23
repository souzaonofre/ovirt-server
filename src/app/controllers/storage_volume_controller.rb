#
# Copyright (C) 2009 Red Hat, Inc.
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

class StorageVolumeController < ApplicationController

  def new
    @return_to_workflow = params[:return_to_workflow] || false
    if params[:storage_pool_id]
      @storage_pool = StoragePool.find(params[:storage_pool_id])
      unless @storage_pool.user_subdividable
        #fixme: proper error page for popups
        redirect_to :controller => 'dashboard'
        return
      end
      new_volume_internal(@storage_pool,
                          { :storage_pool_id => params[:storage_pool_id]})
    else
      @source_volume = StorageVolume.find(params[:source_volume_id])
      unless @source_volume.supports_lvm_subdivision
        #fixme: proper error page for popups
        redirect_to :controller => 'dashboard'
        return
      end
      lvm_pool = @source_volume.lvm_storage_pool
      unless lvm_pool
        # FIXME: what should we do about VG/LV names?
        # for now auto-create VG name as ovirt_vg_#{@source_volume.id}
        new_params = { :vg_name => "ovirt_vg_#{@source_volume.id}",
          :hardware_pool_id => @source_volume.storage_pool.hardware_pool_id}
        lvm_pool = StoragePool.factory(StoragePool::LVM, new_params)
        lvm_pool.source_volumes << @source_volume
        lvm_pool.save!
      end
      new_volume_internal(lvm_pool, { :storage_pool_id => lvm_pool.id})
      @storage_volume.lv_owner_perms='0744'
      @storage_volume.lv_group_perms='0744'
      @storage_volume.lv_mode_perms='0744'
    end
    render :layout => 'popup'
  end

  def create
    begin
      StorageVolume.transaction do
        @storage_volume.save!
        @task = StorageVolumeTask.new({ :user        => @user,
                              :task_target => @storage_volume,
                              :action      => StorageVolumeTask::ACTION_CREATE_VOLUME,
                              :state       => Task::STATE_QUEUED})
        @task.save!
      end
      respond_to do |format|
        format.json { render :json => { :object => "storage_volume",
            :success => true,
            :alert => "Storage Volume was successfully created." ,
            :new_volume => @storage_volume.storage_tree_element({:filter_unavailable => false, :state => 'new'})} }
        format.xml { render :xml => @storage_volume,
            :status => :created,
            # FIXME: create storage_volume_url method if relevant
            :location => storage_pool_url(@storage_volume)
        }
      end
    rescue => ex
      # FIXME: need to distinguish volume vs. task save errors
      respond_to do |format|
        format.json {
          json_hash = { :object => "storage_volume", :success => false,
            :errors => @storage_volume.errors.localize_error_messages.to_a  }
          json_hash[:message] = ex.message if json_hash[:errors].empty?
          render :json => json_hash }
        format.xml { render :xml => @storage_volume.errors,
          :status => :unprocessable_entity }
      end
    end
  end

  def show
    @storage_volume = StorageVolume.find(params[:id])
    set_perms(@storage_volume.storage_pool.hardware_pool)
    @storage_pool = @storage_volume.storage_pool
    unless @can_view
      flash[:notice] = 'You do not have permission to view this storage volume: redirecting to top level'
      respond_to do |format|
        format.html { redirect_to :controller => 'dashboard' }
        format.json { redirect_to :controller => 'dashboard' }
        format.xml { head :forbidden }
      end
    else
      respond_to do |format|
        format.html { render :layout => 'selection' }
        format.json do
          attr_list = []
          attr_list << :id if (@storage_pool.user_subdividable and @can_modify)
          attr_list += [:display_name, :size_in_gb, :get_type_label]
          json_list(@storage_pool.storage_volumes, attr_list)
        end
        format.xml { render :xml => @storage_volume.to_xml }
      end
    end
  end

  def destroy
    @storage_volume = StorageVolume.find(params[:id])
    set_perms(@storage_volume.storage_pool.hardware_pool)
    unless @can_modify and @storage_volume.storage_pool.user_subdividable
      respond_to do |format|
        format.json { render :json => { :object => "storage_volume",
            :success => false,
            :alert => "You do not have permission to delete this storage volume." } }
        format.xml { head :forbidden }
      end
    else
      alert, success = delete_volume_internal(@storage_volume)
      respond_to do |format|
        format.json { render :json => { :object => "storage_volume",
            :success => success, :alert => alert } }
        format.xml { head(success ? :ok : :method_not_allowed) }
      end
    end
  end

  def pre_create
    volume = params[:storage_volume]
    unless type = params[:storage_type]
      type = volume.delete(:storage_type)
    end
    @storage_volume = StorageVolume.factory(type, volume)
    @perm_obj = @storage_volume.storage_pool.hardware_pool
    authorize_admin
  end

  private
  def new_volume_internal(storage_pool, new_params)
    @storage_volume = StorageVolume.factory(storage_pool.get_type_label, new_params)
    @perm_obj = @storage_volume.storage_pool.hardware_pool
    authorize_admin
  end

  def delete_volume_internal(volume)
    begin
      name = volume.display_name
      if !volume.vms.empty?
        vm_list = volume.vms.collect {|vm| vm.description}.join(", ")
        ["Storage Volume #{name} must be unattached from VMs (#{vm_list}) before deleting it.",
         false]
      else
        volume.state=StorageVolume::STATE_PENDING_DELETION
        volume.save!
        @task = StorageVolumeTask.new({ :user        => @user,
                              :task_target => volume,
                              :action      => StorageVolumeTask::ACTION_DELETE_VOLUME,
                              :state       => Task::STATE_QUEUED})
        @task.save!
        ["Storage Volume #{name} deletion was successfully queued.", true]
      end
    rescue => ex
      ["Failed to delete storage volume #{name} (#{ex.message}.",false]
    end
  end

end
