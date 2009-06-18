
class VmPoolController < AgentController

  include VmResourcePoolService

  # Every controller should implement the 'find' method.  This is called in order
  # to convert an 'id' to a real object.  In this case we use svc_show(id), where
  # ID is the active record ID.  @pool is then set to the pool active record
  # and we use 'render' (implemented below) to convert that record from an
  # active record to a QMF object.
  def find(id)
    svc_show(id)
    render(@pool)
  end

  # This should return QMF objects for every instance of this type.  In this
  # case we are using active record directly to find all the vm pool records,
  # but we should be using the vm pool service class to do this so that we
  # get the right permissions.
  #
  # Again we use render to convert the active record objects into QMF objects.
  #
  # In the future this may take arguments that define search criteria.
  def list
    puts "query for VMPool class!"
    # Return all VmPool objects. FIXME: Use VmPoolService to list pools's
    VmResourcePool.find(:all).collect { |pool| render(pool) }
  end

  # Here we are converting the active record into a QMF object.  This is
  # then returned to the console/client.  The QMF objects require that all
  # the properties be set (well, should be set anyway) and they require an
  # ID.  The ID we assign is a combination of the 'class' or type id followed
  # by the active record ID.  These are the same IDs used to identify the
  # object later, eg when 'find' is used or a method is called on an object.
  #
  # The framework itself sorts out the class ID and calls this class for each
  # method in the XML while the second part of the ID gets passed in.  Here
  # we use the active record ID.
  #
  # The one tricky thing here is setting the reference to the parent hardware pool.
  # This requires that we set the 'class id' using HardwarePoolController.schema_class.id
  # to get its class ID, and do not use our own ID.  We also then use the active record ID
  # of the hardware pool.  Now if the client/console wants to get a real object from that
  # reference the controller can 'render' it automatically.
  def render(pool)
    qmf_pool = Qmf::QmfObject.new(schema_class)
    qmf_pool[:name] = pool.name
    puts "#{HardwarePoolController.schema_class.id}, #{pool.get_hardware_pool.id}"
    qmf_pool[:hardware_pool] = @agent.encode_id(HardwarePoolController.schema_class.id, pool.get_hardware_pool.id)
    qmf_pool.set_object_id(encode_id(pool.id))

    # TODO: Need to add quota stuff..

    return qmf_pool
  end

  # So this is the implementation of an actual method as defined in the XML.
  # Each method defined for the class should be implemented in the controller,
  # and this includes an settable properties which will also be implemented
  # as method calls (which will usually use svc_updated).
  #
  # Note that we use 'extend VmService' here as this method requires that we
  # use that service to create a new instance.  This seems to be working pretty
  # well.
  #
  # The 'args' variable is defined in the parent AgentController class and will
  # be set to the arguments for the method.  'args' looks like a normal ruby
  # hash but is actually a QMF type so not all things are supported by it and
  # we generally have to convert this to a native ruby hash in order to call
  # into the service layer, as can be seen here.  We should probably create
  # something like the 'to_qmf' method to easily convert argument names, or
  # sometimes it's easier just to change the XML spec so the names align with
  # the active record names.
  #
  # Arguments in the hash follow the XML API spec automatically including output
  # argument names.  To set the output argument, just set args[output] to the
  # appropriate value.  Here you can see us setting args['vm'] to the newly
  # created VM object ID.
  #
  # This method returns a reference to the newly created VM definition object.
  # Note that once again we must use the VmDefController.schema_class.id in order
  # to properly convert that instance into a locally identifyable ID.
  def create_vm_def
    extend VmService

    # FIXME: any hope of implementing to_hash on the qmf hash in args?
    vm_hash = {}
    args.each do |key, value|
      vm_hash[key] = value
    end
    vm_hash.delete('vm')
    vm_hash.delete('uuid') if args['uuid'] == ''
    vm_hash.delete('vnic_mac_addr') if args['vnic_mac_addr'] == ''
    vm_hash['vm_resource_pool_id'] = id
    # FIXME: Current svc/model API expects provisioning_and_boot_settings to be
    #        set here rather than setting boot_device directly to hd, pxe, etc.
    vm_hash['boot_device'] = '/dev/sda1'

    svc_create(vm_hash, false)

    args['vm'] = @agent.encode_id(VmDefController.schema_class.id, @vm.id)
  end

end

