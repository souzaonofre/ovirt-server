class OvirtController < AgentController

  include VmService

  # Special gymnastics since this is a singleton class
  def self.setup(agent)
    @@instance = Qmf::QmfObject.new(schema_class)
    @@instance[:version] = "0.0.0.1"
    obj_id = agent.encode_id(schema_class.id, 1)
    @@instance.set_object_id(obj_id)

  end

  def self.instance
    @@instance
  end

  def find(id)
    if id == 1
      # This class is a singleton so it's easy.. :)
      @@instance
    end
  end

  def list
    [ @@instance ]
  end

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

    # Set our DIR_OUT argument to the object id of our new vm.
    args['vm'] = encode_id(@vm.id)
  end
end

