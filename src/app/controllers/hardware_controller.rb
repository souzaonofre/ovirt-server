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

class HardwareController < PoolController
  include HardwarePoolService

  EQ_ATTRIBUTES = [ :name, :parent_id ]

  verify :method => [:post, :put], :only => [ :create, :update ],
         :redirect_to => { :action => :list }
  verify :method => [:post, :delete], :only => :destroy,
         :redirect_to => { :action => :list }

  before_filter :pre_modify, :only => [:move, :removestorage]

  def index
    if params[:path]
      @pools = []
      pool = HardwarePool.find_by_path(params[:path])
      @pools << pool if pool
    else
      conditions = []
      EQ_ATTRIBUTES.each do |attr|
        if params[attr]
          conditions << "#{attr} = :#{attr}"
        end
      end

      @pools = HardwarePool.find(:all,
                 :conditions => [conditions.join(" and "), params],
                 :order => "id")
    end

    respond_to do |format|
      format.xml {
        opts = XML_OPTS.dup
        opts[:include] = opts[:include].inject({}) { |m, k| m[k] = {}; m }
        opts[:include][:hosts] = { :include => :cpus }
        render :xml => @pools.to_xml(opts)
      }
    end
  end

  def json_view_tree
    json_tree_internal(Privilege::VIEW, :select_hardware_and_vm_pools)
  end
  def json_move_tree
    json_tree_internal(Privilege::MODIFY, :select_hardware_pools)
  end
  def json_tree_internal(privilege, filter_method)
    id = params[:id]
    if id
      @pool = Pool.find(id)
      set_perms(@pool)
      return unless authorize_action(privilege)
    end
    if @pool
      pools = @pool.children
      open_list = []
    else
      pools = Pool.list_for_user(get_login_user,Privilege::VIEW)
      hw_root = HardwarePool.get_default_pool
      if !(pools.include?(hw_root))
        if pools.include?(DirectoryPool.get_directory_root)
          pools << hw_root
        elsif pools.include?(DirectoryPool.get_hardware_root)
          pools << hw_root
        end
      end
      current_id = params[:current_id]
      if current_id
        current_pool = Pool.find(current_id)
        open_list = current_pool.self_and_ancestors
      else
        open_list = []
      end
    end
    pools = Pool.send(filter_method, pools)

    render :json => Pool.nav_json(pools, open_list,
                                  (filter_method==:select_hardware_pools))
  end

  def show_vms
    show
  end

  def show_hosts
    show
  end

  def show_graphs
    show
  end

  def show_storage
    begin
      svc_show(params[:id])
      @storage_tree = @pool.storage_tree(:filter_unavailable => false,
                                         :include_used => true).to_json
      render_show
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
    end
  end

  def show_tasks
    @task_types = Task::TASK_TYPES_OPTIONS
    super
  end

  def hosts_json
    if params[:exclude_host]
      pre_show_pool
      hosts = @pool.hosts
      find_opts = {:conditions => ["id != ?", params[:exclude_host]]}
      include_pool = false
    elsif params[:id]
      pre_show_pool
      hosts = @pool.hosts
      find_opts = {}
      include_pool = false
    else
      # FIXME: no permissions or usage checks here yet
      # filtering on which pool to exclude
      id = params[:exclude_pool]
      hosts = Host
      find_opts = {:include => :hardware_pool,
        :conditions => ["pools.id != ?", id]}
      include_pool = true
    end
    super(:full_items => hosts,:include_pool => include_pool,:find_opts => find_opts)
  end

  def vm_pools_json
    json_list(Pool,
              [:id, :name, :id],
              [@pool, :children],
              {:finder => 'call_finder', :conditions => ["type = 'VmResourcePool'"]})
  end

  def storage_pools_json
    if params[:id]
      pre_show_pool
      storage_pools = @pool.storage_pools
      find_opts = {:conditions => "type != 'LvmStoragePool'"}
      include_pool = false
    else
      # FIXME: no permissions or usage checks here yet
      # filtering on which pool to exclude
      id = params[:exclude_pool]
      storage_pools = StoragePool
      find_opts = {:include => :hardware_pool,
        :conditions => ["(storage_pools.type != 'LvmStoragePool') and (pools.id != ?)", id]}
      include_pool = true
    end
    super(:full_items => storage_pools,:include_pool => include_pool,:find_opts => find_opts)
  end

  def storage_volumes_json
    json_list(@pool.all_storage_volumes,
              [:display_name, :size_in_gb, :get_type_label])
  end

  def move
    @resource_type = params[:resource_type]
    @id = params[:id]
    @pools = HardwarePool.get_default_pool.full_set_nested(:method => :json_hash_element,
                       :privilege => Privilege::MODIFY, :user => get_login_user, :current_id => @id,
                       :type => :select_hardware_pools).to_json
    render :layout => 'popup'
  end

  def new
    @resource_type = params[:resource_type]
    @resource_ids = params[:resource_ids]
    super
  end

  def additional_create_params
    {:resource_type => params[:resource_type],
      :resource_ids => params[:resource_ids],
      :parent_id => (params[:hardware_pool] ?
                     params[:hardware_pool][:parent_id] :
                     params[:parent_id])}
  end

  def add_hosts
    edit_items(@pool.id, :svc_move_hosts, :add)
  end

  def move_hosts
    edit_items(params[:target_pool_id], :svc_move_hosts, :move)
  end

  def add_storage
    edit_items(@pool.id, :svc_move_storage, :add)
  end

  def move_storage
    edit_items(params[:target_pool_id], :svc_move_storage, :move)
  end

  def edit_items(svc_method, target_pool_id, item_action)
    begin
      alert = send(svc_method, params[:id], params[:resource_ids].split(","),
                   target_pool_id)
      render :json => { :success => true, :alert => alert,
                        :storage => @pool.storage_tree({:filter_unavailable =>
                                                        false,
                                                        :include_used => true,
                                                        :state =>
                                                        item_action.to_s})}
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
      # If we need to give more details as to which hosts/storage succeeded,
      # they're in the exception
    rescue PartialSuccessError => error
      render :json => { :success => false, :alert => error.message }
    rescue Exception => ex
      render :json => { :success => false, :alert => error.message }
    end
  end

  def removestorage
    render :layout => 'popup'
  end


  protected
  #filter methods
  def pre_new
    @pool = HardwarePool.new
    super
  end
  def pre_edit
    @pool = HardwarePool.find(params[:id])
    @parent = @pool.parent
    set_perms(@pool)
  end
  def pre_modify
    pre_edit
    authorize_admin
  end
end
