module Ovirt
  class VmDefController < AgentController

    include VmService

    def find(id)
      svc_show(id)
      render(@vm)
    end

    def list
      puts "query for VmDef class!"
      # FIXME: what about filter params?
      svc_list
      @vms.collect { |vm| render(vm) }
    end

    def render(vm)
      to_qmf(vm, :propmap => { :mac => :vnic_mac_addr } )
    end

    # FIXME: do I need to report the status message
    # FIXME: where is exception handling done here?
    # FIXME comment applies to all methods below
    def delete
      alert = svc_destroy(id)
    end

    # FIXME: we need a host ID reference to pass as the third arg to svc_vm_action
    #        This arg isn't in the xml def right now, but I'm not sure how to
    #        specify this right now.
    def migrate
      vm_action(VmTask::ACTION_MIGRATE_VM, nil)
    end

    def start
      vm_action(VmTask::ACTION_START_VM)
    end

    def shutdown
      vm_action(VmTask::ACTION_SHUTDOWN_VM)
    end

    def poweroff
      vm_action(VmTask::ACTION_POWEROFF_VM)
    end

    def suspend
      vm_action(VmTask::ACTION_SUSPEND_VM)
    end

    def resume
      vm_action(VmTask::ACTION_RESUME_VM)
    end

    private
    def vm_action(action, task_arg=nil)
      alert = svc_vm_action(id, action, task_arg)
      # FIXME: no TaskController yet. do we need to worry about name conflicts
      #        w/ WUI controllers?
      args['task'] = @agent.encode_id(TaskController.schema_class.id, @task.id)
    end

  end
end
