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
  include StoragePoolService

  EQ_ATTRIBUTES = [ :ip_addr, :export_path, :target,
                    :hardware_pool_id ]

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
    #no permissions here yet -- do we disable raw volume list
    conditions = []
    EQ_ATTRIBUTES.each { |attr|
      conditions << "#{attr} = :#{attr}" if params[attr]
    }

    @storage_pools = StoragePool.find(:all,
              :conditions => [conditions.join(" and "), params],
              :order => "id")
  end

  def show
    svc_show(params[:id])
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

  def new
    svc_load_hw_pool(params[:hardware_pool_id])
    @storage_types = StoragePool::STORAGE_TYPE_PICKLIST
    render :layout => false
  end

  def new2
    svc_new(params[:hardware_pool_id], params[:storage_type])
    render :layout => false
  end

  def refresh
    alert = svc_refresh(params[:id])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  def create
    pool = params[:storage_pool]
    unless type = params[:storage_type]
      type = pool.delete(:storage_type)
    end
    alert = svc_create(type, pool)
    respond_to do |format|
      format.json { render :json => { :object => "storage_pool",
          :success => true, :alert => alert,
          :new_pool => @storage_pool.storage_tree_element({:filter_unavailable => false, :state => 'new'})} }
      format.xml { render :xml => @storage_pool,
        :status => :created,
        :location => storage_pool_url(@storage_pool)
      }
     end
  end

  def edit
    svc_modify(params[:id])
    render :layout => 'popup'
  end

  def update
    alert = svc_update(params[:id], params[:storage_pool])
    render :json => { :object => "storage_pool", :success => true,
                      :alert => alert }
  end

  def addstorage
    svc_load_hw_pool(params[:hardware_pool_id])
    @storage_types = StoragePool::STORAGE_TYPE_PICKLIST
    render :layout => 'popup'    
  end

  def add
    svc_load_hw_pool(params[:hardware_pool_id])
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
    storage_pool_ids = params[:storage_pool_ids].split(",")
    successes = []
    failures = {}
    storage_pool_ids.each do |storage_pool_id|
      begin
        svc_destroy(storage_pool_id)
        successes << @storage_pool
      rescue PermissionError => perm_error
        failures[@storage_pool] = perm_error.message
      rescue Exception => ex
        failures[@storage_pool] = ex.message
      end
    end
    unless failures.empty?
      raise PartialSuccessError.new("Delete failed for some Storage Pools",
                                    failures, successes)
    end
    render :json => { :object => "storage_pool", :success => true,
                      :alert => "Storage Pools were successfully deleted." }
  end

  def destroy
    alert = svc_destroy(params[:id])
    respond_to do |format|
      format.json { render :json => { :object => "storage_pool",
          :success => true, :alert => alert } }
      format.xml { head(:ok) }
    end
  end
end
