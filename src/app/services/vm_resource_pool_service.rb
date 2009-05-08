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

  # Load the VmResourcePool with +id+ for editing
  #
  # === Instance variables
  # [<tt>@pool</tt>] stores the Pool with +id+
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the parent pool
  def svc_modify(id)
    lookup(id, Privilege::MODIFY, true)
  end

  # Load a new VmResourcePool for creating
  #
  # === Instance variables
  # [<tt>@pool</tt>] loads a new VmResourcePool object into memory
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt> as specified by
  #                    +parent_id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the parent pool
  def svc_new(parent_id, attributes=nil)
    @pool = VmResourcePool.new(attributes)
    super(parent_id)
  end

  # Save a new VmResourcePool
  #
  # === Instance variables
  # [<tt>@pool</tt>] the newly saved VmResourcePool
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt> as specified by
  #                    +parent_id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the parent pool
  def svc_create(pool_hash, other_args)
    svc_new(other_args[:parent_id], pool_hash)
    @pool.create_with_parent(@parent)
    return "VM Pool was successfully created."
  end

  # Perform action +vm_action+ on vms identified by +vm_id+ within Pool
  #  +pool_id+
  #
  # === Instance variables
  # [<tt>@pool</tt>] the current VmResourcePool
  # [<tt>@parent</tt>] the parent of <tt>@pool</tt>
  # [<tt>@action</tt>] action identified by +vm_action+
  # [<tt>@action_label</tt>] label for action identified by +vm_action+
  # [<tt>@vms</tt>] VMs identified by +vm_ids+
  # === Required permissions
  # permission is action-specific as determined by
  #   <tt>VmTask.action_privilege(@action)</tt>
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
      raise PartialSuccessError.new("#{@action} failed for some VMs",
                                    failed_vms, successful_vms)
    end
    return "Action #{@action} successful."
  end

end
