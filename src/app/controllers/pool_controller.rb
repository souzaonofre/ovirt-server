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

  before_filter :pre_show_pool, :only => [:users_json, :show_tasks, :tasks,
                                          :vm_pools_json,
                                          :pools_json, :storage_volumes_json]

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
    begin
      svc_show(params[:id])
      render_show
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
    end
  end

  def render_show
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
    begin
      svc_show(params[:id])
      render :layout => 'selection'
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
    end
  end

  # resource's users list page
  def show_users
    @roles = Role.find(:all).collect{ |role| [role.name, role.id] }
    show
  end

  def users_json
    attr_list = []
    attr_list << :grid_id if params[:checkboxes]
    attr_list += [:uid, [:role, :name], :source]
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

  def create
    # FIXME: REST and browsers send params differently. Should be fixed
    # in the views
    begin
      alert = svc_create(params[:pool] ? params[:pool] : params[:hardware_pool],
                         additional_create_params)
      respond_to do |format|
        format.json {
          reply = { :object => "pool", :success => true,
            :alert => alert }
          reply[:resource_type] = params[:resource_type] if params[:resource_type]
          render :json => reply
        }
        format.xml {
          render :xml => @pool.to_xml(XML_OPTS),
          :status => :created,
          :location => hardware_pool_url(@pool)
        }
      end
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
    rescue Exception => ex
      respond_to do |format|
        format.json { json_error("pool", @pool, ex) }
        format.xml  { render :xml => @pool.errors,
          :status => :unprocessable_entity }
      end
    end
  end

  def update
    begin
      alert = svc_update(params[:id], params[:pool] ? params[:pool] :
                                      params[:hardware_pool])
      respond_to do |format|
        format.json {
          reply = { :object => "pool", :success => true, :alert => alert }
          render :json => reply
        }
        format.xml {
          render :xml => @pool.to_xml(XML_OPTS),
          :status => :created,
          :location => hardware_pool_url(@pool)
        }
      end
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
    rescue Exception => ex
      respond_to do |format|
        format.json { json_error("pool", @pool, ex) }
        format.xml  { render :xml => @pool.errors,
          :status => :unprocessable_entity }
      end
    end
  end

  def additional_create_params
    {}
  end

  def edit
    render :layout => 'popup'
  end

  def destroy
    alert = nil
    success = true
    status = :ok
    begin
      alert = svc_destroy(params[:id])
    rescue ActionError => error
      alert = error.message
      success = false
      status = :conflict
    rescue PermissionError => error
      alert = error.message
      success = false
      status = :forbidden
    rescue Exception => error
      alert = error.message
      success = false
      status = :method_not_allowed
    end
    respond_to do |format|
      format.json { render :json => { :object => "pool", :success => success,
          :alert => alert } }
      format.xml { head status }
    end
  end

  protected
  def pre_new
    @parent = Pool.find(params[:parent_id])
    set_perms(@parent)
  end
  def pre_show_pool
    @pool = Pool.find(params[:id])
    set_perms(@pool)
    authorize_view
  end
  # FIXME: remove these when service transition is complete. these are here
  # to keep from running permissions checks and other setup steps twice
  def tmp_pre_update
  end
  def tmp_authorize_admin
  end

end
