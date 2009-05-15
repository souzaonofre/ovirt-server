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

  def show_tasks
    svc_show(params[:id])
    super
  end

  def tasks
    svc_show(params[:id])
    super
  end

  def show
    svc_show(params[:id])
    render_show
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
    svc_show(params[:id])
    render :layout => 'selection'
  end

  # resource's users list page
  def show_users
    @roles = Role.find(:all).collect{ |role| [role.name, role.id] }
    show
  end

  def users_json
    svc_show(params[:id])
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
    svc_new(get_parent_id)
    render :layout => 'popup'
  end

  def create
    # FIXME: REST and browsers send params differently. Should be fixed
    # in the views
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
  end

  def update
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
  end

  def additional_create_params
    {}
  end

  def edit
    svc_modify(params[:id])
    render :layout => 'popup'
  end

  def destroy
    alert = svc_destroy(params[:id])
    respond_to do |format|
      format.json { render :json => { :object => "pool", :success => true,
          :alert => alert } }
      format.xml { head(:ok) }
    end
  end

  protected
  def get_parent_id
    params[:parent_id]
  end
end
