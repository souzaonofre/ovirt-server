#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>,
#            David Lutterkort <lutter@redhat.com>
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
# Mid-level API: Business logic around VM pools
module VmResourcePoolService

  include PoolService

  def svc_create(pool_hash, other_args)
    # from before_filter
    @pool = VmResourcePool.new(pool_hash)
    @parent = Pool.find(other_args[:parent_id])
    authorized!(Privilege::MODIFY,@parent)

    alert = "VM Pool was successfully created."
    @pool.create_with_parent(@parent)
    return alert
  end

  def update_perms
    @current_pool_id=@pool.id
    set_perms(@pool.parent)
  end

  def svc_vm_actions(pool_id, vm_action, vm_ids)
    # from before_filter
    @pool = VmResourcePool.find(pool_id)
    @parent = @pool.parent
    @action = vm_action
    @action_label = VmTask.action_label(@action)
    authorized!(VmTask.action_privilege(@action),
                VmTask.action_privilege_object(@action,@pool))

    @vms = Vm.find(vm_ids)

    successful_vms = []
    failed_vms = {}
    @vms.each do |vm|
      begin
        if vm.vm_resource_pool != @pool
          failed_vms[vm] = "VM #{vm.description} does not belong to the current pool."
        elsif vm.queue_action(@user, @action)
          successful_vms << vm
        else
          failed_vms[vm] = "unavailable action"
        end
      rescue Exception => ex
        failed_vms[vm] = ex.message
      end
    end
    unless failed_vms.empty?
      raise PartialSuccessError.new("#{@action} only partially successful",
                                    failed_vms, successful_vms)
    end
    return "Action #{@action} successful."
  end



end
