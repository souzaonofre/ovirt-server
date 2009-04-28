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
    @actions = [VmTask.label_and_action(VmTask::ACTION_START_VM),
                VmTask.label_and_action(VmTask::ACTION_SHUTDOWN_VM),
                (VmTask.label_and_action(VmTask::ACTION_POWEROFF_VM) << "break"),
                VmTask.label_and_action(VmTask::ACTION_SUSPEND_VM),
                VmTask.label_and_action(VmTask::ACTION_RESUME_VM),
                VmTask.label_and_action(VmTask::ACTION_SAVE_VM),
                VmTask.label_and_action(VmTask::ACTION_RESTORE_VM)]
    show
  end

  def tasks_internal
    @task_type = ""
    @task_state = params[:task_state]
    super
  end

  def vms_json
    pre_show_pool
    super(:full_items => @pool.vms, :find_opts => {}, :include_pool => :true)
  end

  def additional_create_params
    {:parent_id => (params[:hardware_pool] ?
                    params[:hardware_pool][:parent_id] :
                    params[:parent_id])}
  end

   #FIXME: we need permissions checks. user must have permission. We also need to fail
  # for pools that aren't currently empty
  def delete
    vm_pool_ids = params[:vm_pool_ids].split(",")
    successes = []
    failures = {}
    vm_pool_ids.each do |pool_id|
      begin
        svc_destroy(pool_id)
        successes << @pool
      rescue PermissionError => perm_error
        failures[@pool] = perm_error.message
      rescue Exception => ex
        failures[@pool] = ex.message
      end
    end
    success = failures.empty?
    alert = ""
    if !successes.empty?
      alert = "Virtual Machine Pools #{successes.collect{|pool| pool.name}.join(', ')} were successfully deleted."
    end
    if !failures.empty?
      alert += " Errors in deleting VM Pools #{failures.collect{|pool,err| "#{pool.name}: #{err}"}.join(', ')}."
    end
    render :json => { :object => "vm_resource_pool", :success => success,
                      :alert => alert }
  end

  def vm_actions
    begin
      alert = svc_vm_actions_hosts(params[:id], params[:vm_action],
                                   params[:vm_ids].split(","))
      @success_list = @vms
      @failures = {}
      render :layout => 'confirmation'
    rescue PermissionError
      raise
    rescue PartialSuccessError => error
      @success_list = error.successes
      @failures = error.failures
      render :layout => 'confirmation'
    rescue Exeption => ex
      flash[:errmsg] = 'Error queueing VM actions.'
      @success_list = []
      @failure_list = []
    end
  end

  protected
  def pre_new
    @pool = VmResourcePool.new
    super
  end
  def pre_edit
    @pool = VmResourcePool.find(params[:id])
    @parent = @pool.parent
    @current_pool_id=@pool.id
    set_perms(@pool.parent)
  end

end
