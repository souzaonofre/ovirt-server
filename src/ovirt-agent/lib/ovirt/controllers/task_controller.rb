module Ovirt
  class TaskController < AgentController

    include TaskService

    def find(id)
      svc_show(id)
      render(@task)
    end

    def list
      puts "query for Task class!"
      # FIXME: what about filter params?, use svc layer for permissions filtering
      Task.find(:all).collect { |task| render(task) }
    end

    def render(task)
      # FIXME: propmap?
      to_qmf(task)
    end

    def cancel
      alert = svc_cancel(id)
    end

  end
end
