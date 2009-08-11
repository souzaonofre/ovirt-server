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
  include SmartPoolService

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
    svc_show(params[:id])
    @storage_tree = @pool.storage_tree(:filter_unavailable => false, :include_used => true).to_json
    render_show
  end

  def additional_create_params
    {}
  end

  def add_pool_dialog
    svc_modify(params[:id])
    @selected_pools = @pool.tagged_pools.collect {|pool| pool.id}
    render :layout => 'popup'
  end

  def hosts_json
    super(items_json_internal(Host, :tagged_hosts))
  end

  def storage_pools_json
    args = items_json_internal(StoragePool, :tagged_storage_pools)
    conditions = args[:find_opts][:conditions]
    storage_conditions = "storage_pools.type != 'LvmStoragePool'"
    if conditions[0]
      conditions[0] = "(#{storage_conditions}) and (#{conditions[0]})"
    else
      conditions[0] = storage_conditions
    end
    super(args)
  end

  def vms_json
    super(items_json_internal(Vm, :tagged_vms, {:select => Vm.calc_uptime}))
  end

  def pools_json
    args = items_json_internal(Pool, :tagged_pools)
    attr_list = [:id, :name, :get_type_label]
    json_list(args[:full_items], attr_list, [:all], args[:find_opts], :class_and_id)

  end

  def items_json_internal(item_class, item_assoc, find_opts = {})
    if params[:id]
      svc_show(params[:id])
      full_items = @pool.send(item_assoc)
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
      find_opts[:conditions] = conditions
      include_pool = true
    end
    { :full_items => full_items, :find_opts => find_opts, :include_pool => include_pool}
  end

  def add_hosts
    add_or_remove_items(Host, :add)
  end

  def remove_hosts
    add_or_remove_items(Host, :remove)
  end

  def add_storage
    add_or_remove_items(StoragePool, :add)
  end

  def remove_storage
    add_or_remove_items(StoragePool, :remove)
  end

  def add_vms
    add_or_remove_items(Vm, :add)
  end

  def remove_vms
    add_or_remove_items(Vm, :remove)
  end

  def add_pools
    add_or_remove_items(Pool, :add)
  end

  def remove_pools
    add_or_remove_items(Pool, :remove)
  end

  def add_or_remove_items(item_class, item_action)
    alert = svc_add_remove_items(params[:id], item_class, item_action,
                                 params[:resource_ids].split(","))
    render :json => { :success => true, :alert => alert}
  end

  def add_items
    class_and_ids_str = params[:class_and_ids]
    class_and_ids = class_and_ids_str.split(",").collect do |class_and_id_str|
      class_and_id = class_and_id_str.split("_")
      class_and_id[0] = class_and_id[0].constantize
      class_and_id
    end

    alert = svc_add_remove_items(params[:id], nil, :add, class_and_ids)
    render :json => { :success => true, :alert => alert}
  end

  protected
  def get_parent_id
    DirectoryPool.get_or_create_user_root(get_login_user).id
  end

end
