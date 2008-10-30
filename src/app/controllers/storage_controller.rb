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

class StorageController < ApplicationController

  EQ_ATTRIBUTES = [ :ip_addr, :export_path, :target,
                    :hardware_pool_id ]

  before_filter :pre_pool_admin, :only => [:refresh]
  before_filter :pre_new2, :only => [:new2]
  before_filter :pre_json, :only => [:storage_volumes_json]
  before_filter :pre_create_volume, :only => [:create_volume]

  def index
    list
    respond_to do |format|
      format.html { render :action => 'list' }
      format.xml { render :xml => @storage_pools.to_xml }
    end
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => [:post, :put], :only => [ :create, :update ],
         :redirect_to => { :action => :list }
  verify :method => [:post, :delete], :only => :destroy,
         :redirect_to => { :action => :list }

  def list
    @attach_to_pool=params[:attach_to_pool]
    if @attach_to_pool
      pool = HardwarePool.find(@attach_to_pool)
      set_perms(pool)
      unless @can_view
        flash[:notice] = 'You do not have permission to view this storage pool list: redirecting to top level'
        redirect_to :controller => 'dashboard'
      else
        conditions = "hardware_pool_id is null"
        conditions += " or hardware_pool_id=#{pool.parent_id}" if pool.parent
        @storage_pools = StoragePool.find(:all, :conditions => conditions)
      end
    else
      #no permissions here yet -- do we disable raw volume list
      conditions = []
      EQ_ATTRIBUTES.each { |attr|
        conditions << "#{attr} = :#{attr}" if params[attr]
      }

      @storage_pools = StoragePool.find(:all,
              :conditions => [conditions.join(" and "), params],
              :order => "id")
    end
  end

  def show
    @storage_pool = StoragePool.find(params[:id])
    set_perms(@storage_pool.hardware_pool)
    unless @can_view
      flash[:notice] = 'You do not have permission to view this storage pool: redirecting to top level'
      respond_to do |format|
        format.html { redirect_to :controller => 'dashboard' }
        format.xml { head :forbidden }
      end
    else
      respond_to do |format|
        format.html { render :layout => 'selection' }
        format.xml { render :xml => @storage_pool.to_xml }
      end
    end
  end

  def storage_volumes_json
    @storage_pool = StoragePool.find(params[:id])
    set_perms(@storage_pool.hardware_pool)
    unless @can_view
      flash[:notice] = 'You do not have permission to view this storage pool: redirecting to top level'
      redirect_to :controller => 'dashboard'
    end
    attr_list = []
    attr_list << :id if (@storage_pool.user_subdividable and @can_modify)
    attr_list += [:display_name, :size_in_gb, :get_type_label]
    json_list(@storage_pool.storage_volumes, attr_list)
  end
  def show_volume
    @storage_volume = StorageVolume.find(params[:id])
    set_perms(@storage_volume.storage_pool.hardware_pool)
    unless @can_view
      flash[:notice] = 'You do not have permission to view this storage volume: redirecting to top level'
      respond_to do |format|
        format.html { redirect_to :controller => 'dashboard' }
        format.xml { head :forbidden }
      end
    else
      respond_to do |format|
        format.html { render :layout => 'popup' }
        format.xml { render :xml => @storage_volume.to_xml }
      end
    end
  end

  def new
  end

  def new2
    @storage_pools = @storage_pool.hardware_pool.storage_volumes
    render :layout => false
  end

  def new_volume
    new_volume_internal(StoragePool.find(params[:storage_pool_id]),
                        { :storage_pool_id => params[:storage_pool_id]})
    render :layout => 'popup'
  end

  def new_lvm_volume
    @source_volume = StorageVolume.find(params[:source_volume_id])
    @return_facebox = params[:return_facebox]
    unless @source_volume.supports_lvm_subdivision
      #fixme: proper error page for popups
      redirect_to :controller => 'dashboard'
      return
    end
    lvm_pool = @source_volume.lvm_storage_pool
    unless lvm_pool
      # FIXME: what should we do about VG/LV names?
      # for now auto-create VG name as ovirt_vg_#{@source_volume.id}
      lvm_pool = LvmStoragePool.new(:vg_name => "ovirt_vg_#{@source_volume.id}",
              :hardware_pool_id => @source_volume.storage_pool.hardware_pool_id)
      lvm_pool.source_volumes << @source_volume
      lvm_pool.save!
    end
    new_volume_internal(lvm_pool, { :storage_pool_id => lvm_pool.id})
    @storage_volume.lv_owner_perms='0744'
    @storage_volume.lv_group_perms='0744'
    @storage_volume.lv_mode_perms='0744'
    render :layout => 'popup'
  end

  def create_volume
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
            :alert => "Storage Volume was successfully created." } }
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

  def insert_refresh_task
    @task = StorageTask.new({ :user        => @user,
                              :task_target => @storage_pool,
                              :action      => StorageTask::ACTION_REFRESH_POOL,
                              :state       => Task::STATE_QUEUED})
    @task.save!
  end

  def refresh
    begin
      insert_refresh_task
      storage_url = url_for(:controller => "storage", :action => "show", :id => @storage_pool)
      flash[:notice] = 'Storage pool refresh was successfully scheduled.'
    rescue
      flash[:notice] = 'Error scheduling Storage pool refresh.'
    end
    redirect_to :action => 'show', :id => @storage_pool.id
  end

  def create
    begin
      StoragePool.transaction do
        @storage_pool.save!
        insert_refresh_task
      end
      respond_to do |format|
        format.json { render :json => { :object => "storage_pool",
            :success => true,
            :alert => "Storage Pool was successfully created." } }
        format.xml { render :xml => @storage_pool,
            :status => :created,
            :location => storage_pool_url(@storage_pool)
        }
      end
    rescue => ex
      # FIXME: need to distinguish pool vs. task save errors (but should mostly be pool)
      respond_to do |format|
        format.json {
          json_hash = { :object => "storage_pool", :success => false,
            :errors => @storage_pool.errors.localize_error_messages.to_a  }
          json_hash[:message] = ex.message if json_hash[:errors].empty?
          render :json => json_hash }
        format.xml { render :xml => @storage_pool.errors,
          :status => :unprocessable_entity }
      end
    end
  end

  def edit
    render :layout => 'popup'    
  end

  def update
    begin
      StoragePool.transaction do
        @storage_pool.update_attributes!(params[:storage_pool])
        insert_refresh_task
      end
      render :json => { :object => "storage_pool", :success => true, 
                        :alert => "Storage Pool was successfully modified." }
    rescue
      # FIXME: need to distinguish pool vs. task save errors (but should mostly be pool)
      render :json => { :object => "storage_pool", :success => false, 
                        :errors => @storage_pool.errors.localize_error_messages.to_a  }
    end
  end

  def add_internal
    @hardware_pool = HardwarePool.find(params[:hardware_pool_id])
    @perm_obj = @hardware_pool
    @redir_controller = @perm_obj.get_controller
    authorize_admin
    @storage_pools = @hardware_pool.storage_volumes
    @storage_types = StoragePool::STORAGE_TYPE_PICKLIST
  end

  def addstorage
    add_internal
    render :layout => 'popup'    
  end

  def add
    add_internal
    render :layout => false
  end

  def new
    add_internal
    render :layout => false
  end

  def add_to_smart_pool
    @pool = SmartPool.find(params[:smart_pool_id])
    render :layout => 'popup'
  end

  #FIXME: we need permissions checks. user must have permission on src pool
  # in addition to the current pool (which is checked). We also need to fail
  # for storage that aren't currently empty
  def delete_pools
    storage_pool_ids_str = params[:storage_pool_ids]
    storage_pool_ids = storage_pool_ids_str.split(",").collect {|x| x.to_i}

    begin
      StoragePool.transaction do
        storage = StoragePool.find(:all, :conditions => "id in (#{storage_pool_ids.join(', ')})")
        storage.each do |storage_pool|
          storage_pool.destroy
        end
      end
      render :json => { :object => "storage_pool", :success => true, 
        :alert => "Storage Pools were successfully deleted." }
    rescue
      render :json => { :object => "storage_pool", :success => true, 
        :alert => "Error deleting storage pools." }
    end
  end

  def destroy
    pool = @storage_pool.hardware_pool
    if @storage_pool.destroy
      alert="Storage Pool was successfully deleted."
      success=true
    else
      alert="Failed to delete storage pool."
      success=false
    end
    respond_to do |format|
      format.json { render :json => { :object => "storage_pool",
          :success => success, :alert => alert } }
      format.xml { head(success ? :ok : :method_not_allowed) }
    end
  end

  def delete_volumes
    storage_volume_ids_str = params[:storage_volume_ids]
    storage_volume_ids = storage_volume_ids_str.split(",").collect {|x| x.to_i}
    alerts = []
    status = true
    begin
      StorageVolume.transaction do
        storage = StorageVolume.find(:all, :conditions => "id in (#{storage_volume_ids.join(', ')})")
        unless storage.empty?
          set_perms(storage[0].storage_pool.hardware_pool)
          unless @can_modify and storage[0].storage_pool.user_subdividable
            respond_to do |format|
              format.json { render :json => { :object => "storage_volume",
                  :success => false,
                  :alert => "You do not have permission to delete this storage volume." } }
              format.xml { head :forbidden }
            end
          else
            storage.each do |storage_volume|
              alert, success = delete_volume_internal(storage_volume)
              alerts << alert
              status = false unless success
            end
            respond_to do |format|
              format.json { render :json => { :object => "storage_volume",
                  :success => status, :alert => alerts.join("\n") } }
              format.xml { head(status ? :ok : :method_not_allowed) }
            end
          end
        else
          respond_to do |format|
            format.json { render :json => { :object => "storage_volume",
                :success => false, :alert => "no volumes selected" } }
            format.xml { head(status ? :ok : :method_not_allowed) }
          end
        end
      end
    end
  end

  def delete_volume
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

  def pre_new
    @hardware_pool = HardwarePool.find(params[:hardware_pool_id])
    @perm_obj = @hardware_pool
    @redir_controller = @perm_obj.get_controller
  end

  def pre_new2
    new_params = { :hardware_pool_id => params[:hardware_pool_id]}
    if (params[:storage_type] == "iSCSI")
      new_params[:port] = 3260
    end
    @storage_pool = StoragePool.factory(params[:storage_type], new_params)
    @perm_obj = @storage_pool.hardware_pool
    @redir_controller = @storage_pool.hardware_pool.get_controller
    authorize_admin
  end
  def pre_create
    pool = params[:storage_pool]
    unless type = params[:storage_type]
      type = pool.delete(:storage_type)
    end
    @storage_pool = StoragePool.factory(type, pool)
    @perm_obj = @storage_pool.hardware_pool
    @redir_controller = @storage_pool.hardware_pool.get_controller
  end
  def pre_edit
    @storage_pool = StoragePool.find(params[:id])
    @perm_obj = @storage_pool.hardware_pool
    @redir_obj = @storage_pool
  end
  def pre_create_volume
    volume = params[:storage_volume]
    unless type = params[:storage_type]
      type = volume.delete(:storage_type)
    end
    @storage_volume = StorageVolume.factory(type, volume)
    @perm_obj = @storage_volume.storage_pool.hardware_pool
    @redir_controller = @storage_volume.storage_pool.hardware_pool.get_controller
    authorize_admin
  end
  def pre_json
    pre_show
  end
  def pre_pool_admin
    pre_edit
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
        #FIXME: create delete volume task. include metadata in task
      else
        #FIXME: need to set volume to 'unavailable' state once we have states
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
