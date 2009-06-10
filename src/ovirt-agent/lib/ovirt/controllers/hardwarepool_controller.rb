

class HardwarePoolController < AgentController

  include HardwarePoolService

  def find(id)
    svc_show(id)
    render(@pool)
  end

  def list
    puts "query for HardwarePool class!"
    # Return all VmDef objects. FIXME: Use HardwarePoolService to list pools's
    HardwarePool.find(:all).collect { |pool| render(pool) }
  end

  def render(pool)
    puts "calling to_qmf on #{pool}, #{pool.name}"
    to_qmf(pool, :propmap => { :parent => :ignore,
                               :nodes => :ignore,
                               :storage_pools => :ignore,
                               :vm_pools => :ignore,
                               :children => :ignore })
  end
end

