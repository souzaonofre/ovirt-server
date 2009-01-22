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
#

class SmartPoolsController < PoolController

  before_filter :pre_modify, :only => [:add_hosts, :remove_hosts,
                                       :add_storage, :remove_storage,
                                       :add_vms, :remove_vms,
                                       :add_pools, :remove_pools,
                                       :add_items, :add_pool_dialog]
  def show_vms
    show
  end

  def show_hosts
    show
  end

  def show_pools
    show
  end

  def show_storage
    @storage_tree = @pool.storage_tree(:filter_unavailable => false, :include_used => true).to_json
    show
  end

  def create
    begin
      @pool.create_with_parent(@parent)
      render :json => { :object => "smart_pool", :success => true,
                        :alert => "Smart Pool was successfully created." }
    rescue
      render :json => { :object => "smart_pool", :success => false,
                        :errors => @pool.errors.localize_error_messages.to_a}
    end
  end

  def update
    begin
      @pool.update_attributes!(params[:smart_pool])
      render :json => { :object => "smart_pool", :success => true,
                        :alert => "Smart Pool was successfully modified." }
    rescue
      render :json => { :object => "smart_pool", :success => false,
                        :errors => @pool.errors.localize_error_messages.to_a}
    end
  end

  def add_pool_dialog
    @selected_pools = @pool.tagged_pools.collect {|pool| pool.id}
    render :layout => 'popup'
  end

  def hosts_json
    super(items_json_internal(Host, :tagged_hosts))
  end

  def storage_pools_json
    args = items_json_internal(StoragePool, :tagged_storage_pools)
    conditions = args[:find_opts][:conditions]
    conditions[0] = "(storage_pools.type != 'LvmStoragePool') and (#{conditions[0]})"
    super(args)
  end

  def vms_json
    super(items_json_internal(Vm, :tagged_vms))
  end

  def pools_json
    args = items_json_internal(Pool, :tagged_pools)
    attr_list = [:id, :name, :get_type_label]
    json_list(args[:full_items], attr_list, [:all], args[:find_opts], :class_and_id)

  end

  def items_json_internal(item_class, item_assoc)
    if params[:id]
      pre_show
      full_items = @pool.send(item_assoc)
      find_opts = {}
      include_pool = false
    else
      # FIXME: no permissions or usage checks here yet
      # filtering on which pool to exclude
      id = params[:exclude_pool]
      full_items = item_class
      pool_items = SmartPool.find(id).send(item_assoc).collect {|x| x.id}
      if pool_items.empty?
        conditions = []
      else
        conditions = ["#{item_class.table_name}.id not in (?)", pool_items]
      end
      find_opts = {:conditions => conditions}
      include_pool = true
    end
    { :full_items => full_items, :find_opts => find_opts, :include_pool => include_pool}
  end

  def add_hosts
    edit_items(Host, :add_items, :add)
  end

  def remove_hosts
    edit_items(Host, :remove_items, :remove)
  end

  def add_storage
    edit_items(StoragePool, :add_items, :add)
  end

  def remove_storage
    edit_items(StoragePool, :remove_items, :remove)
  end

  def add_vms
    edit_items(Vm, :add_items, :add)
  end

  def remove_vms
    edit_items(Vm, :remove_items, :remove)
  end

  def add_pools
    edit_items(Pool, :add_items, :add)
  end

  def remove_pools
    edit_items(Pool, :remove_items, :remove)
  end

  def edit_items(item_class, item_method, item_action)
    resource_ids_str = params[:resource_ids]
    resource_ids = resource_ids_str.split(",").collect {|x| x.to_i}
    begin
      @pool.send(item_method,item_class, resource_ids)
      render :json => { :success => true,
        :alert => "#{item_action.to_s} #{item_class.table_name.humanize} successful." }
    rescue
      render :json => { :success => false,
        :alert => "#{item_action.to_s} #{item_class.table_name.humanize} failed." }
    end
  end

  def add_items
    class_and_ids_str = params[:class_and_ids]
    class_and_ids = class_and_ids_str.split(",").collect {|x| x.split("_")}

    begin
      @pool.transaction do
        class_and_ids.each do |class_and_id|
          @pool.add_item(class_and_id[0].constantize.find(class_and_id[1].to_i))
        end
      end
      render :json => { :success => true,
        :alert => "Add items to smart pool successful." }
    rescue => ex
      render :json => { :success => false,
          :alert => "Add items to smart pool failed: " + ex.message }
    end

  end

  def destroy
    if @pool.destroy
      alert="Smart Pool was successfully deleted."
      success=true
    else
      alert="Failed to delete Smart pool."
      success=false
    end
    render :json => { :object => "smart_pool", :success => success, :alert => alert }
  end

  protected
  #filter methods
  def pre_new
    @pool = SmartPool.new
    @parent = DirectoryPool.get_or_create_user_root(get_login_user)
    @perm_obj = @parent
    @current_pool_id=@parent.id
  end
  def pre_create
    @pool = SmartPool.new(params[:smart_pool])
    @parent = DirectoryPool.get_or_create_user_root(get_login_user)
    @perm_obj = @parent
    @current_pool_id=@parent.id
  end
  def pre_edit
    @pool = SmartPool.find(params[:id])
    @parent = @pool.parent
    @perm_obj = @pool
    @current_pool_id=@pool.id
  end
  def pre_show
    @pool = SmartPool.find(params[:id])
    super
  end
  def pre_modify
    pre_edit
    authorize_admin
  end

end
