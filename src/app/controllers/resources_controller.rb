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

class ResourcesController < PoolController
  include VmResourcePoolService
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list
    @user = get_login_user
    @vm_resource_pools = VmResourcePool.list_for_user(@user, Privilege::VIEW)
    @vms = Set.new
    @vm_resource_pools.each { |vm_resource_pool| @vms += vm_resource_pool.vms}
    @vms = @vms.entries
    @action_values = [["Suspend", VmTask::ACTION_SUSPEND_VM],
                      ["Resume", VmTask::ACTION_RESUME_VM],
                      ["Save", VmTask::ACTION_SAVE_VM],
                      ["Restore", VmTask::ACTION_RESTORE_VM]]
  end

  # resource's summary page
  def show
    @action_values = [["Suspend", VmTask::ACTION_SUSPEND_VM],
                      ["Resume", VmTask::ACTION_RESUME_VM],
                      ["Save", VmTask::ACTION_SAVE_VM],
                      ["Restore", VmTask::ACTION_RESTORE_VM]]
    super
  end

  # resource's vms list page
  def show_vms    
    @actions = VmTask.get_vm_actions
    show
  end

  def tasks_internal
    @task_type = ""
    @task_state = params[:task_state]
    super
  end

  def vms_json
    svc_show(params[:id])
    super(:full_items => @pool.vms, :find_opts => {}, :include_pool => :true)
  end

  def additional_create_params
    {:parent_id => (params[:hardware_pool] ?
                    params[:hardware_pool][:parent_id] :
                    params[:parent_id])}
  end

  def delete
    vm_pool_ids = params[:vm_pool_ids].split(",")
    successes = []
    failures = {}
    vm_pool_ids.each do |pool_id|
      begin
        svc_destroy(pool_id)
        successes << @pool
      # PermissionError expected
      rescue Exception => ex
        failures[@pool.nil? ? pool_id : @pool] = ex.message
      end
    end
    unless failures.empty?
      raise PartialSuccessError.new("Delete failed for some VM Pools",
                                    failures, successes)
    end
    render :json => { :object => "vm_resource_pool", :success => true,
                      :alert => "VM Pools were successfully deleted." }
  end

  def vm_actions
    @layout = 'confirmation'
    alert = svc_vm_actions(params[:id], params[:vm_action],
                           params[:vm_ids].split(","))
    @successes = @vms
    @failures = {}
    render :layout => @layout
  end
end
