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
  before_filter :pre_add, :only => [:add, :addstorage]

  def index
    list
    respond_to do |format|
      format.html { render :action => 'list' }
      # FIXME: For LVM, we are losing the nesting of LVM pool inside
      # an iSCSI volume here
      format.xml { render :xml => @storage_pools.to_xml( :include => :storage_volumes) }
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
      if authorize_view
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
    if authorize_view
      respond_to do |format|
        format.html { render :layout => 'selection' }
        format.xml {
          xml_txt = @storage_pool.to_xml(:include => :storage_volumes) do |xml|
            xml.type @storage_pool.class.name
          end
          render :xml => xml_txt
        }
      end
    end
  end

  def new
  end

  def new2
    @storage_pools = @storage_pool.hardware_pool.storage_volumes
    render :layout => false
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
            :alert => "Storage Pool was successfully created.",
            :new_pool => @storage_pool.storage_tree_element({:filter_unavailable => false, :state => 'new'})} }
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

  def addstorage
    render :layout => 'popup'    
  end

  def add
    render :layout => false
  end

  def new
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
    unless @storage_pool.movable?
      @error = "Cannot delete storage with associated vms"
      respond_to do |format|
        format.json { render :json => { :object => "storage_pool",
            :success => false, :alert => @error } }
        format.xml { render :template => "errors/simple", :layout => false,
          :status => :forbidden }
      end
      return
    end

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

  def pre_new
    @hardware_pool = HardwarePool.find(params[:hardware_pool_id])
    set_perms(@hardware_pool)
    authorize_admin
    @storage_pools = @hardware_pool.storage_volumes
    @storage_types = StoragePool::STORAGE_TYPE_PICKLIST
  end

  def pre_add
    pre_new
  end

  def pre_new2
    new_params = { :hardware_pool_id => params[:hardware_pool_id]}
    if (params[:storage_type] == "iSCSI")
      new_params[:port] = 3260
    end
    @storage_pool = StoragePool.factory(params[:storage_type], new_params)
    set_perms(@storage_pool.hardware_pool)
    authorize_admin
  end
  def pre_create
    pool = params[:storage_pool]
    unless type = params[:storage_type]
      type = pool.delete(:storage_type)
    end
    @storage_pool = StoragePool.factory(type, pool)
    set_perms(@storage_pool.hardware_pool)
  end
  def pre_edit
    @storage_pool = StoragePool.find(params[:id])
    set_perms(@storage_pool.hardware_pool)
  end
  def pre_pool_admin
    pre_edit
    authorize_admin
  end

end
