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
# Mid-level API: Business logic around individual VM's
module VmService

  include ApplicationService

  # Load the Vm with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@vm</tt>] stores the Vm with +id+
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] on vm's VmResourcePool
  def svc_show(id)
    lookup(id,Privilege::VIEW)
  end

  # Load the Vm with +id+ for editing
  #
  # === Instance variables
  # [<tt>@vm</tt>] stores the Vm with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on vm's VmResourcePool
  def svc_modify(id)
    lookup(id,Privilege::MODIFY)
  end

  # Load a new Vm for creating
  #
  # === Instance variables
  # [<tt>@vm</tt>] loads a new Vm object into memory
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the vm's VmResourcePool as specified by
  #                              +vm_resource_pool_id+
  def svc_new(vm_resource_pool_id)
    raise ActionError.new("VM Resource Pool is required.") unless vm_resource_pool_id

    # random MAC
    mac = [ 0x00, 0x16, 0x3e, rand(0x7f), rand(0xff), rand(0xff) ]
    # random uuid
    uuid = ["%02x"*4, "%02x"*2, "%02x"*2, "%02x"*2, "%02x"*6].join("-") %
      Array.new(16) {|x| rand(0xff) }

    @vm = Vm.new({:vm_resource_pool_id => vm_resource_pool_id,
                  :vnic_mac_addr => mac.collect {|x| "%02x" % x}.join(":"),
                  :uuid => uuid })
    authorized!(Privilege::MODIFY, @vm.vm_resource_pool)
  end

  # Save a new Vm
  #
  # === Instance variables
  # [<tt>@vm</tt>] the newly saved Vm
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the vm's VmResourcePool
  def svc_create(vm_hash, start_now)
    # from before_filter
    vm_hash[:state] = Vm::STATE_PENDING
    @vm = Vm.new(vm_hash)
    authorized!(Privilege::MODIFY,@vm.vm_resource_pool)

    alert = "VM was successfully created."
    Vm.transaction do
      @vm.save!
      vm_provision
      @task = VmTask.new({ :user        => @user,
                           :task_target => @vm,
                           :action      => VmTask::ACTION_CREATE_VM,
                           :state       => Task::STATE_QUEUED})
      @task.save!
      if start_now
        if @vm.get_action_list.include?(VmTask::ACTION_START_VM)
          @task = VmTask.new({ :user        => @user,
                               :task_target => @vm,
                               :action      => VmTask::ACTION_START_VM,
                               :state       => Task::STATE_QUEUED})
          @task.save!
          alert += " VM Start action queued."
        else
          alert += " Resources are not available to start VM now."
        end
      end
    end
    return alert
  end

  # Update attributes for the Vm with +id+
  #
  # === Instance variables
  # [<tt>@vm</tt>] stores the Vm with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the Vm's VmResourcePool
  def svc_update(id, vm_hash, start_now, restart_now)
    # from before_filter
    @vm = Vm.find(id)
    authorized!(Privilege::MODIFY, @vm.vm_resource_pool)

    #needs restart if certain fields are changed
    # (since those will only take effect the next startup)
    needs_restart = false
    unless @vm.get_pending_state == Vm::STATE_STOPPED
      Vm::NEEDS_RESTART_FIELDS.each do |field|
        unless @vm[field].to_s == vm_hash[field]
          needs_restart = true
          break
        end
      end
      current_storage_ids = @vm.storage_volume_ids.sort
      new_storage_ids = vm_hash[:storage_volume_ids]
      new_storage_ids = [] unless new_storage_ids
      new_storage_ids = new_storage_ids.sort.collect {|x| x.to_i }
      needs_restart = true unless current_storage_ids == new_storage_ids
    end
    vm_hash[:needs_restart] = 1 if needs_restart


    alert = "VM was successfully updated."
    Vm.transaction do
      @vm.update_attributes!(vm_hash)
      vm_provision
      if start_now
        if @vm.get_action_list.include?(VmTask::ACTION_START_VM)
          @task = VmTask.new({ :user        => @user,
                               :task_target => @vm,
                               :action      => VmTask::ACTION_START_VM,
                               :state       => Task::STATE_QUEUED})
          @task.save!
          alert += " VM Start action queued."
        else
          alert += " Resources are not available to start VM now."
        end
      elsif restart_now
        if @vm.get_action_list.include?(VmTask::ACTION_SHUTDOWN_VM)
          @task = VmTask.new({ :user        => @user,
                               :task_target => @vm,
                               :action      => VmTask::ACTION_SHUTDOWN_VM,
                               :state       => Task::STATE_QUEUED})
          @task.save!
          @task = VmTask.new({ :user    => @user,
                               :task_target => @vm,
                               :action  => VmTask::ACTION_START_VM,
                               :state   => Task::STATE_QUEUED})
          @task.save!
          alert += " VM Restart action queued."
        else
          alert += " Restart action was not available."
        end
      end
    end
    return alert
  end

  # Destroys for the Vm with +id+
  #
  # === Instance variables
  # [<tt>@vm</tt>] stores the Vm with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the Vm's VmResourcePool
  def svc_destroy(id)
    # from before_filter
    @vm = Vm.find(id)
    authorized!(Privilege::MODIFY, @vm.vm_resource_pool)

    unless @vm.is_destroyable?
      raise ActionError.new("Virtual Machine must be stopped to delete it")
    end
    destroy_cobbler_system(@vm)
    @vm.destroy
    return "Virtual Machine was successfully deleted."
  end

  #  Queues action +vm_action+ for Vm with +id+
  #
  # === Instance variables
  # [<tt>@vm</tt>] stores the Vm with +id+
  # === Required permissions
  # permission is action-specific as determined by
  #   <tt>VmTask.action_privilege(@action)</tt>
  def svc_vm_action(id, vm_action, action_args)
    @vm = Vm.find(id)
    authorized!(VmTask.action_privilege(vm_action),
                VmTask.action_privilege_object(vm_action,@vm))
    unless @vm.queue_action(@user, vm_action, action_args)
      raise ActionError.new("#{vm_action} is an invalid action.")
    end
    return "#{vm_action} was successfully queued."
  end

  #  Cancels queued tasks for for Vm with +id+
  #
  # === Instance variables
  # [<tt>@vm</tt>] stores the Vm with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the Vm's VmResourcePool
  def svc_cancel_queued_tasks(id)
    @vm = Vm.find(id)
    authorized!(Privilege::MODIFY, @vm.vm_resource_pool)

    Task.transaction do
      @vm.tasks.queued.each { |task| task.cancel}
    end
    return "Queued tasks were successfully canceled."
  end

  protected
  def vm_provision
    if @vm.uses_cobbler?
      # spaces are invalid in the cobbler name
      name = @vm.uuid
      system = Cobbler::System.find_one(name)
      unless system
        system = Cobbler::System.new("name" => name,
                                     @vm.cobbler_type => @vm.cobbler_name)
        system.interfaces = [Cobbler::NetworkInterface.new(
                                    {'mac_address' => @vm.vnic_mac_addr})]
        system.save
      end
    end
  end

  def destroy_cobbler_system(vm)
    # Destroy the Cobbler system first if it's defined
    if vm.uses_cobbler?
      system = Cobbler::System.find_one(vm.cobbler_system_name)
      system.remove if system
    end
  end

  private
  def lookup(id, priv)
    @vm = Vm.find(id)
    authorized!(priv,@vm.vm_resource_pool)
  end

end
