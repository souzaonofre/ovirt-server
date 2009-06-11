

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

  def create_vm_pool
    extend VmResourcePoolService

    pool_hash = { :name => args['name'] }
    puts "Args are #{args}"
    args.each do |arg, value|
      puts "arg: #{arg} = #{value}"
    end
    puts "pool_hash: #{pool_hash.inspect}"

    svc_create(pool_hash, id, {})
    args['vm_pool'] = encode_id(@pool.id)
  end
end
