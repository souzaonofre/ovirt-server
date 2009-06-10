
class CreateVm < AgentController

  include VmService

  def create_vm_def
    vm_hash = {}
    args.each do |key, value|
      vm_hash[key] = value
    end
    vm_hash.delete('vm')
    vm_hash.delete('uuid') if args['uuid'] == ''
    vm_hash.delete('vnic_mac_addr') if args['vnic_mac_addr'] == ''

    # FIXME: DOH!  Need to implement pools..
    vm_hash['vm_resource_pool_id'] = 5
    # FIXME: This needs to come from the service layer too..
    vm_hash['boot_device'] = '/dev/sda1'
    # FIXME: Scott has made a patch to have these created in the service layer if
    # they are not provided.  Saves duplicating code here.
    vm_hash['uuid'] = '23a4255f-1f0f-c5d2-5f8e-388537fde0b1' if args['uuid'] == ''
    vm_hash['vnic_mac_addr'] = 'AB:CD:EF:00:00:00' if args['vnic_mac_addr'] == ''

    svc_create(vm_hash, false)

    id = encode_id(@vm.id)
    return id
  end
end


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

  def create_vm_def
    foo = VmCreate.new(@context, @agent, @logger, @user_id)
    id = foo.create_vm_def
    args['vm'] = id
  end

end

