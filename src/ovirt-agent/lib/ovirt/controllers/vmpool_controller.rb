
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
    extend VmService

    vm_hash = {}
    args.each do |key, value|
      vm_hash[key] = value
    end
    vm_hash.delete('vm')
    vm_hash.delete('uuid') if args['uuid'] == ''
    vm_hash.delete('vnic_mac_addr') if args['vnic_mac_addr'] == ''
    vm_hash['vm_resource_pool_id'] = id
    # FIXME: This needs to come from the service layer too..
    vm_hash['boot_device'] = '/dev/sda1'

    svc_create(vm_hash, false)

    args['vm'] = encode_id(@vm.id)
  end

end

