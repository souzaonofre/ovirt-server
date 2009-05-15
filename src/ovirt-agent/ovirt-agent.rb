#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "../dutils")

require "rubygems"
require 'monitor'
require 'dutils'
require 'daemons'
require 'logger'

require 'qmf'
require 'socket'

include Daemonize

class VmQmfController
  include VmService

  attr_accessor :vm

  def get_login_user
    return "ovirtadmin"
  end
end


class Ovirt

  TABLE_ID = 1

  def initialize(agent, logger)

    @agent = agent
    @logger = logger

    @ovirt_class = Qmf::SchemaObjectClass.new("org.ovirt.ovirt", "Ovirt")
    @ovirt_class.add_property(Qmf::SchemaProperty.new("version", Qmf::TYPE_SSTR, :access => Qmf::ACCESS_READ_CREATE, :desc => "Ovirt version string"))

    method = Qmf::SchemaMethod.new("create_vm_def", :desc => "Define a new virtual machine definition.")
    method.add_argument(Qmf::SchemaArgument.new("description", Qmf::TYPE_LSTR, :desc => "Description of new VM definition"))
    method.add_argument(Qmf::SchemaArgument.new("num_vcpus_allocated", Qmf::TYPE_UINT32, :desc => "Number of virtual CPUs to allocate."))
    method.add_argument(Qmf::SchemaArgument.new("memory_allocated", Qmf::TYPE_UINT64, :desc => "Amount of memory to allocate.", :units => "KB"))
    method.add_argument(Qmf::SchemaArgument.new("uuid", Qmf::TYPE_SSTR, :desc => "UUID of VM, will be assigned if left empty."))
    method.add_argument(Qmf::SchemaArgument.new("vnic_mac_addr", Qmf::TYPE_SSTR, :desc => "MAC address of virtual NIC, will be assigned if left empty."))
    method.add_argument(Qmf::SchemaArgument.new("vm", Qmf::TYPE_REF, :desc => "Newly created domain object id.", :dir => Qmf::DIR_OUT))
    @ovirt_class.add_method(method)

    @agent.register_class(@ovirt_class)
  end

  def start
    @ovirt = Qmf::QmfObject.new(@ovirt_class)
    @ovirt.set_attr("version", "0.0.0.1")

    obj_id = @agent.alloc_object_id(1, Ovirt::TABLE_ID)
    @ovirt.set_object_id(obj_id)
  end

  def implement_id_query(context, id)
    if id == 1
      # This class is a singleton so it's easy.. :)
      @agent.query_response(context, @ovirt)
    end
  end

  def implement_class_query(context)
    puts "query for 'Ovirt' object"
    @agent.query_response(context, @ovirt)
  end

  def implement_method_call(context, name, object_num_low, args)
    case name
    when 'create_vm_def'
      # args is a Qmf::Arguments and is not a real hash even though it implements [], each etc.
      vm_hash = {}
      args.each do |key, value|
        puts "key is #{key}, value is #{args[key]}"
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

      vmsvc = VmQmfController.new
      vmsvc.svc_create(vm_hash, false)

      # Set our DIR_OUT argument to the object id of our new vm.
      args['vm'] = @agent.alloc_object_id(vmsvc.vm.id, VmDef::TABLE_ID)
      @agent.method_response(context, 0, "OK", args)
    end
  end
end

class VmDef

  TABLE_ID = 2

  def initialize(agent, logger)

    @agent = agent
    @logger = logger

    @vmdef_class = Qmf::SchemaObjectClass.new("org.ovirt.ovirt", "VmDef")
    @vmdef_class.add_property(Qmf::SchemaProperty.new("description", Qmf::TYPE_LSTR, :desc => "VM description/name."))
    @vmdef_class.add_property(Qmf::SchemaProperty.new("num_vcpus_allocated", Qmf::TYPE_UINT32, :desc => "Number of virtual CPUs to allocate to VM."))
    @vmdef_class.add_property(Qmf::SchemaProperty.new("memory_allocated", Qmf::TYPE_UINT64, :units => 'KB', :desc => "Amount of memory to allocate to VM."))
    @vmdef_class.add_property(Qmf::SchemaProperty.new("mac", Qmf::TYPE_SSTR, :access => Qmf::ACCESS_READ_CREATE, :desc => "VM virtual network card MAC address."))
    @vmdef_class.add_property(Qmf::SchemaProperty.new("uuid", Qmf::TYPE_SSTR, :access => Qmf::ACCESS_READ_CREATE, :desc => "VM description/name."))
    @vmdef_class.add_property(Qmf::SchemaProperty.new("provisioning", Qmf::TYPE_LSTR, :access => Qmf::ACCESS_READ_WRITE, :desc => "VM description/name."))
    @vmdef_class.add_property(Qmf::SchemaProperty.new("needs_restart", Qmf::TYPE_BOOL, :access => Qmf::ACCESS_READ_ONLY, :desc => "VM description/name."))
    @vmdef_class.add_property(Qmf::SchemaProperty.new("state", Qmf::TYPE_SSTR, :access => Qmf::ACCESS_READ_ONLY, :desc => "Current state of VM instance."))

    @agent.register_class(@vmdef_class)
  end

  def ar_to_object(ar_vm)

    vmdef = Qmf::QmfObject.new(@vmdef_class)
    vmdef.set_attr("description", ar_vm.description)
    vmdef.set_attr("num_vcpus_allocated", ar_vm.num_vcpus_allocated)
    vmdef.set_attr("memory_allocated", ar_vm.memory_allocated)
    vmdef.set_attr("uuid", ar_vm.uuid)
    vmdef.set_attr("mac", ar_vm.vnic_mac_addr)
    vmdef.set_attr("provisioning", ar_vm.provisioning)
    vmdef.set_attr("needs_restart", ar_vm.needs_restart)
    vmdef.set_attr("state", ar_vm.state)

    # Set the 'low' part of the local object ID to the VM row id, and the
    # 'high' part of the local object id to the table ID.  Table ID here
    # must then be unique for every class/table.
    vmdef.set_object_id(@agent.alloc_object_id(ar_vm.id, VmDef::TABLE_ID))

    return vmdef
  end

  def implement_id_query(context, id)
    vmsvc = VmQmfController.new
    vmsvc.svc_show(id)
    vmdef = ar_to_object(vmsvc.vm)
    @agent.query_response(context, vmdef) if vmdef
  end

  def implement_class_query(context)
    vmsvc = VmQmfController.new

    puts "query for VmDef class!"
    # Return all VmDef objects.
    ar_vms = Vm.find(:all)
    ar_vms.each do |ar_vm|
      begin
        vmsvc.svc_show(ar_vm.id)
        vmdef = ar_to_object(vmsvc.vm)
        @agent.query_response(context, vmdef)
      rescue Exception => ex
        @logger.info "Couldn't get svc_show to show vm record: #{ex}"
      end
    end
  end

  def implement_method_call(context, method)
  end

end

class OvirtAgent < Qmf::AgentHandler

  def initialize

    ensure_credentials

    @logger = Logger.new(STDERR)

    server, port = nil
    sleepy = 5
    while true do
      server, port = get_srv('qpidd', 'tcp')
      break if server
      @logger.error "Unable to determine qpid server from DNS SRV record, retrying.." if not server
      sleep(sleepy)
      sleepy *= 2 if sleepy < 120
    end

    @settings = Qmf::ConnectionSettings.new
    #@settings.server = server
    #@settings.port = port
    #@settings.mechanism = 'GSSAPI'

    @settings.host = 'mc.mains.net'

    @connection = Qmf::Connection.new(@settings)
    @agent = Qmf::Agent.new(self)

    @ovirt_model = Ovirt.new(@agent, @logger)
    @vmdef_model = VmDef.new(@agent, @logger)

    # Create a hash which maps "table ID"s to specific models.  This
    # number is then encoded into the local part of the object ID so
    # we always know what object type and database row the object id
    # refers to.
    @table_id_map = { Ovirt::TABLE_ID => @ovirt_model,
                      VmDef::TABLE_ID => @vmdef_model
                    }
  end

  # This method is called when a console does a search for a specific
  # object.  It should use query_response() to return the matching objects
  # and then query_complete() when done.
  def get_query(context, query)

    begin
      puts "Query: context=#{context} class=#{query.class_name} object_id=#{query.object_id}"

      if query.object_id != nil
        object_num_low = query.object_id.object_num_low
        object_num_high = query.object_id.object_num_high

        puts "Query: object_num=#{object_num_low},#{object_num_high}"

        # We use object_num_high (32 bit int) to denote the table or class type,
        # and object_num_low (32 bits also) to denote the row ID in the database.
        begin
          cls = @table_id_map[object_num_high]
          cls.implement_id_query(context, object_num_low)
          @agent.query_complete(context)
          return
        rescue Exception => ex
          @logger.info "Couldn't map ID to object: #{ex}"
          @logger.info ex.backtrace
        end

        @agent.query_complete(context)
        return
      end

      @table_id_map.each do |id, cls|
        begin
          puts "checking against class #{cls.class.to_s}"
          if query.class_name == cls.class.to_s
            cls.implement_class_query(context)
            puts "query complete..."
            @agent.query_complete(context)
            puts "yes"
            return
          end
        rescue Exception => ex
          @logger.error "Error performing class name query ovirt-agent: #{ex}"
          @logger.error ex.backtrace
        end
      end

    rescue Exception => ex
      @logger.error "Error in ovirt-agent: #{ex}"
      @logger.error ex.backtrace
    end

    puts "empty return!"
    @agent.query_complete(context)

  end


  # This is called when an incoming method is requested of an object.
  def method_call(context, name, object_id, args)
    begin
      object_num_low = object_id.object_num_low
      object_num_high = object_id.object_num_high

      puts "Method: context=#{context} method=#{name} object_num=#{object_num_low},#{object_num_high} args=#{args}"
      cls = @table_id_map[object_num_high]
      cls.implement_method_call(context, name, object_num_low, args)
    rescue Exception => ex
      @logger.info "Error implementing method in ovirt-agent: #{ex}"
      @logger.info ex.backtrace
      @agent.method_response(context, 1, "ERROR: #{ex}", args)
    end
  end


  def ensure_credentials()
    get_credentials('qpidd')

    Thread.new do
      while true do
        sleep(3600)
        get_credentials('qpidd')
      end
    end
  end

  def mainloop
    Thread.abort_on_exception = true

    @agent.set_connection(@connection)

    @ovirt_model.start

    sleep
  end
end


ovirt_agent = OvirtAgent.new
ovirt_agent.mainloop


