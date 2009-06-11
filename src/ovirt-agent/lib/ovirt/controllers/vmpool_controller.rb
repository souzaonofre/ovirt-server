
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


class VmPoolController < AgentController

  include VmResourcePoolService

  def find(id)
    svc_show(id)
    render(@pool)
  end

  def list
    puts "query for VMPool class!"
    # Return all VmPool objects. FIXME: Use VmPoolService to list pools's
    VmResourcePool.find(:all).collect { |pool| render(pool) }
  end

  def render(pool)
    qmf_pool = Qmf::QmfObject.new(schema_class)
    qmf_pool[:name] = pool.name
    puts "#{HardwarePoolController.schema_class.id}, #{pool.get_hardware_pool.id}"
    qmf_pool[:hardware_pool] = @agent.encode_id(HardwarePoolController.schema_class.id, pool.get_hardware_pool.id)
    qmf_pool.set_object_id(encode_id(pool.id))

    # TODO: Need to add quota stuff..

    return qmf_pool
  end

  def create_vm_def
    foo = VmCreate.new(@context, @agent, @logger, @user_id)
    id = foo.create_vm_def
    args['vm'] = id
  end

end

