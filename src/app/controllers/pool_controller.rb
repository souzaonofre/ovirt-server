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

class PoolController < ApplicationController

  before_filter :pre_show_pool, :only => [:show_vms, :show_users,
                                          :show_hosts, :show_storage,
                                          :users_json, :show_tasks, :tasks,
                                          :vm_pools_json,
                                          :pools_json, :show_pools,
                                          :storage_volumes_json, :quick_summary]

  XML_OPTS  = {
    :include => [ :storage_pools, :hosts, :quota ]
  }

  include TaskActions
  def tasks_query_obj
    @pool.tasks
  end
  def tasks_conditions
    {}
  end

  def show
    respond_to do |format|
      format.html {
        render :layout => 'tabs-and-content' if params[:ajax]
        render :layout => 'help-and-content' if params[:nolayout]
      }
      format.xml {
        render :xml => @pool.to_xml(XML_OPTS)
      }
    end
  end

  def quick_summary
    render :layout => 'selection'
  end

  # resource's users list page
  def show_users
    @roles = Permission::ROLES.keys
    show
  end

  def users_json
    attr_list = []
    attr_list << :grid_id if params[:checkboxes]
    attr_list += [:uid, :user_role, :source]
    json_list(@pool.permissions, attr_list)
  end

  def hosts_json(args)
    attr_list = []
    attr_list << :id if params[:checkboxes]
    attr_list << :hostname
    attr_list << [:hardware_pool, :name] if args[:include_pool]
    attr_list += [:uuid, :hypervisor_type, :num_cpus, :cpu_speed, :arch, :memory_in_mb, :status_str, :load_average]
    json_list(args[:full_items], attr_list, [:all], args[:find_opts])
  end

  def storage_pools_json(args)
    attr_list = [:id, :display_name, :ip_addr, :get_type_label]
    attr_list.insert(2, [:hardware_pool, :name]) if args[:include_pool]
    json_list(args[:full_items], attr_list, [:all], args[:find_opts])
  end

  def vms_json(args)
    attr_list = [:id, :description, :uuid,
                 :num_vcpus_allocated, :memory_allocated_in_mb,
                 :vnic_mac_addr, :state, :id]
    if (@pool.is_a? VmResourcePool) and @pool.get_hardware_pool.can_view(@user)
      attr_list.insert(3, [:host, :hostname])
    end
    json_list(args[:full_items], attr_list, [:all], args[:find_opts])
  end

  def new
    render :layout => 'popup'
  end

  def edit
    render :layout => 'popup'
  end

  protected
  def pre_new
    @parent = Pool.find(params[:parent_id])
    @perm_obj = @parent
    @current_pool_id=@parent.id
  end
  def pre_create
    #this is currently only true for the rest API for hardware pools
    if params[:hardware_pool]
      @parent = Pool.find(params[:hardware_pool][:parent_id])
    else
      @parent = Pool.find(params[:parent_id])
    end
    @perm_obj = @parent
    @current_pool_id=@parent.id
  end
  def pre_show_pool
    pre_show
  end
  def pre_show
    @perm_obj = @pool
    @current_pool_id=@pool.id
    set_perms(@perm_obj)
    unless @can_view
      flash[:notice] = 'You do not have permission to view this pool: redirecting to top level'
      respond_to do |format|
        format.html { redirect_to :controller => "dashboard" }
        format.xml { head :forbidden }
      end
      return
    end
  end

end
