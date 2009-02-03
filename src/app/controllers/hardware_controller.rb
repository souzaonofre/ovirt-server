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

  EQ_ATTRIBUTES = [ :name, :parent_id ]

  verify :method => [:post, :put], :only => [ :create, :update ],
         :redirect_to => { :action => :list }
  verify :method => [:post, :delete], :only => :destroy,
         :redirect_to => { :action => :list }

  before_filter :pre_modify, :only => [:add_hosts, :move_hosts,
                                       :add_storage, :move_storage,
                                       :create_storage, :delete_storage,
                                       :move, :removestorage]

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
    json_tree_internal(Permission::PRIV_VIEW, :select_hardware_and_vm_pools)
  end
  def json_move_tree
    json_tree_internal(Permission::PRIV_MODIFY, :select_hardware_pools)
  end
  def json_tree_internal(privilege, filter_method)
    id = params[:id]
    if id
      @pool = Pool.find(id)
      set_perms(@pool)
      unless @pool.has_privilege(@user, privilege)
        flash[:notice] = 'You do not have permission to access this hardware pool: redirecting to top level'
        redirect_to :controller => "dashboard"
        return
      end
    end
    if @pool
      pools = @pool.children
      open_list = []
    else
      pools = Pool.list_for_user(get_login_user,Permission::PRIV_VIEW)
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
    @storage_tree = @pool.storage_tree(:filter_unavailable => false, :include_used => true).to_json
    show
  end

  def show_tasks
    @task_types = Task::TASK_TYPES_OPTIONS
    super
  end

  def hosts_json
    if params[:exclude_host]
      pre_show
      hosts = @pool.hosts
      find_opts = {:conditions => ["id != ?", params[:exclude_host]]}
      include_pool = false
    elsif params[:id]
      pre_show
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
      pre_show
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
                       :privilege => Permission::PRIV_MODIFY, :user => get_login_user, :current_id => @id,
                       :type => :select_hardware_pools).to_json
    render :layout => 'popup'
  end

  def new
    @resource_type = params[:resource_type]
    @resource_ids = params[:resource_ids]
    super
  end

  def create
    resource_type = params[:resource_type]
    resource_ids_str = params[:resource_ids]
    resource_ids = []
    resource_ids = resource_ids_str.split(",").collect {|x| x.to_i} if resource_ids_str
    begin
      @pool.create_with_resources(@parent, resource_type, resource_ids)
      respond_to do |format|
        format.html {
          reply = { :object => "pool", :success => true,
            :alert => "Hardware Pool was successfully created." }
          reply[:resource_type] = resource_type if resource_type
          render :json => reply
        }
        format.xml {
          render :xml => @pool.to_xml(XML_OPTS),
          :status => :created,
          :location => hardware_pool_url(@pool)
        }
      end
    rescue
      respond_to do |format|
        format.json {
          render :json => { :object => "pool", :success => false,
            :errors => @pool.errors.localize_error_messages.to_a  }
        }
        format.xml  { render :xml => @pool.errors,
          :status => :unprocessable_entity }
      end
    end
  end

  def update
    if params[:hardware_pool]
      # FIXME: For the REST API, we allow moving hosts/storage through
      # update.  It makes that operation convenient for clients, though makes
      # the implementation here somewhat ugly.
      [:hosts, :storage_pools].each do |k|
        objs = params[:hardware_pool].delete(k)
        ids = objs.reject{ |obj| obj[:hardware_pool_id] == @pool.id}.
          collect{ |obj| obj[:id] }
        if ids.size > 0
          # FIXME: use self.move_hosts/self.move_storage
          if k == :hosts
            @pool.move_hosts(ids, @pool.id)
          else
            @pool.move_storage(ids, @pool.id)
          end
        end
      end
      # FIXME: HTML views should use :hardware_pool
      params[:pool] = params.delete(:hardware_pool)
    end

    begin
      @pool.update_attributes!(params[:pool])
      respond_to do |format|
        format.json {
          render :json => { :object => "pool", :success => true,
            :alert => "Hardware Pool was successfully modified." }
        }
        format.xml {
          render :xml => @pool.to_xml(XML_OPTS),
          :status => :created,
          :location => hardware_pool_url(@pool)
        }
      end
    rescue
      respond_to do |format|
        format.json {
          render :json => { :object => "pool", :success => false,
            :errors => @pool.errors.localize_error_messages.to_a}
        }
        format.xml {
          render :xml => @pool.errors,
          :status => :unprocessable_entity
        }
      end
    end
  end

  def add_hosts
    edit_items(Host, :move_hosts, @pool.id, :add)
  end

  def move_hosts
    edit_items(Host, :move_hosts, params[:target_pool_id], :move)
  end

  def add_storage
    edit_items(StoragePool, :move_storage, @pool.id, :add)
  end

  def move_storage
    edit_items(StoragePool, :move_storage, params[:target_pool_id], :move)
  end

  #FIXME: we need permissions checks. user must have permission on src pool
  # in addition to the current pool (which is checked). We also need to fail
  # for storage that aren't currently empty
  def edit_items(item_class, item_method, target_pool_id, item_action)
    resource_ids_str = params[:resource_ids]
    resource_ids = resource_ids_str.split(",").collect {|x| x.to_i}

    # if user doesn't have modify permission on both source and destination
    unless @pool.can_modify(@user) and Pool.find(target_pool_id).can_modify(@user)
        render :json => { :success => false,
               :alert => "Cannot #{item_action.to_s} #{item_class.table_name.humanize} without admin permissions on both pools" }
        return
    end

    # relay error message if movable check fails for any resource
    success = true
    failed_resources = ""
    resource_ids.each {|x|
       unless item_class.find(x).movable?
         success = false
         failed_resources += x.to_s + " "
       end
    }
    resource_ids.delete_if { |x| ! item_class.find(x).movable? }

    begin
      @pool.transaction do
        @pool.send(item_method, resource_ids, target_pool_id)
      end
    rescue
      success = false
    end

    if success
      render :json => { :success => true,
        :alert => "#{item_action.to_s} #{item_class.table_name.humanize} successful.",
        :storage => @pool.storage_tree({:filter_unavailable => false, :include_used => true, :state => item_action.to_s})}
    else
      render :json => { :success => false,
         :alert => "#{item_action.to_s} #{item_class.table_name.humanize} failed" +
                   (failed_resources == "" ? "." : " for " + failed_resources) }
    end
  end

  def removestorage
    render :layout => 'popup'
  end

  def destroy
    parent = @pool.parent
    if not(parent)
      alert="You can't delete the top level Hardware pool."
      success=false
      status=:method_not_allowed
    elsif not(@pool.children.empty?)
      alert = "You can't delete a Pool without first deleting its children."
      success=false
      status=:conflict
    else
      if @pool.move_contents_and_destroy
        alert="Hardware Pool was successfully deleted."
        success=true
        status=:ok
      else
        alert="Failed to delete hardware pool."
        success=false
        status=:internal_server_error
      end
    end
    respond_to do |format|
      format.json { render :json => { :object => "pool", :success => success,
                                      :alert => alert } }
      format.xml { head status }
    end
   end

  protected
  #filter methods
  def pre_new
    @pool = HardwarePool.new
    super
  end
  def pre_create
    # FIXME: REST and browsers send params differently. Should be fixed
    # in the views
    if params[:pool]
      @pool = HardwarePool.new(params[:pool])
    else
      @pool = HardwarePool.new(params[:hardware_pool])
    end
    super
  end
  def pre_edit
    @pool = HardwarePool.find(params[:id])
    @parent = @pool.parent
    @perm_obj = @pool
    @current_pool_id=@pool.id
  end
  def pre_show
    @pool = HardwarePool.find(params[:id])
    super
  end
  def pre_modify
    pre_edit
    authorize_admin
  end
end
