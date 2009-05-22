#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "../dutils")
$: << File.join(File.dirname(__FILE__), "lib")

SCHEMA_XML = File.join(File.dirname(__FILE__), "ovirt_api.xml")

require "rubygems"
require 'monitor'
require 'dutils'
require 'daemons'
require 'logger'

require 'qmf'
require 'socket'

require 'ovirt'

include Daemonize

# Monkey patch
class Qmf::SchemaObjectClass
  attr_reader :id

  def id
    name.hash & 0xffff
  end

  def name
    impl.getName
  end
end

class Qmf::Agent

  # We use object_num_high (32 bit int) to denote the controller class
  # and object_num_low (32 bits also) to denote the row ID in the database.

  def controller_id(object_id)
    object_id.object_num_high
  end

  def row_id(object_id)
    object_id.object_num_low
  end

  def decode_id(object_id)
    [ controller_id(object_id), row_id(object_id) ]
  end

  def encode_id(controller_id, row_id)
    alloc_object_id(row_id, controller_id)
  end
end

class ControllerNotFoundError < StandardError ; end

# The base class for all QMF controllers
#
# Right after the agent is initialized, the +schema_class+ class attribute
# is set, and the +setup+ class method is called with the agent as its only
# argument
class AgentController
  class_inheritable_accessor :schema_class

  attr_reader :agent, :logger
  attr_accessor :args

  def initialize(context, agent, logger)
    @context = context
    @agent = agent
    @logger = logger
    @args = {}
  end

  def schema_class
    self.class.schema_class
  end

  def encode_id(row_id)
    @agent.encode_id(schema_class.id, row_id)
  end

  # FIXME: Get the actual user from the QMF session
  def get_login_user
    return "ovirtadmin"
  end

  # Subclasses should have
  #
  #   find(id) : look up object with that id and return the QMF object
  #   list     : return list of all QMF objects
  #
  #   methods with the same name as defined in the schema
  #     arguments can be accessed through method 'args'
end

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
    puts "query for 'Ovirt' object"
    [ @@instance ]
  end

  def create_vm_def
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

    svc_create(vm_hash, false)

    # Set our DIR_OUT argument to the object id of our new vm.
    args['vm'] = encode_id(@vm.id)
  end
end

class VmDefController < AgentController

  include VmService

  def ar_to_object(ar_vm)

    vmdef = Qmf::QmfObject.new(schema_class)
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
    vmdef.set_object_id(encode_id(ar_vm.id))

    return vmdef
  end

  def find(id)
    svc_show(id)
    ar_to_object(@vm)
  end

  def list
    puts "query for VmDef class!"
    # Return all VmDef objects. FIXME: Use VmService
    ar_vms = Vm.find(:all)
    ar_vms.collect { |ar_vm| ar_to_object(ar_vm) }
  end

end

class OvirtAgent < Qmf::AgentHandler

  include Ovirt::SchemaParser

  def initialize(host)

    ensure_credentials

    @logger = Logger.new(STDERR)
    @logger.level = Logger::DEBUG

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

    @settings.host = host
    @logger.info "Connect to broker on #{@settings.host}"

    @connection = Qmf::Connection.new(@settings)
    @agent = Qmf::Agent.new(self)
    @agent.set_connection(@connection)

    @schema_classes = schema_parse(SCHEMA_XML)

    # Create a hash which maps "table ID"s to specific models.  This
    # number is then encoded into the local part of the object ID so
    # we always know what object type and database row the object id
    # refers to.
    @controller_classes = @schema_classes.inject({}) do |map, klass|
      begin
        controller_class = "#{klass.name}Controller".constantize
        raise NameError unless controller_class < AgentController
        map[klass.id] = controller_class
        controller_class.schema_class = klass
      rescue NameError
        @logger.info "No controller for #{klass.name}"
      end
      map
    end

    @controller_classes.values.each do |controller_class|
      @logger.info "Register #{controller_class.schema_class.name} => #{controller_class.name}"
      @agent.register_class(controller_class.schema_class)
    end

  end

  # This method is called when a console does a search for a specific
  # object.  It should use query_response() to return the matching objects
  # and then query_complete() when done.
  def get_query(context, query, user_id)
    @logger.error "********** get_query"
    begin
      @logger.debug "Query: context=#{context} class=#{query.class_name} object_id=#{query.object_id}"
      @logger.debug "User ID: #{user_id}"

      if query.object_id
        # Lookup individual object
        controller_id, row_id = @agent.decode_id(object_id)

        @logger.debug "Query: object_num=#{controller_id}:#{row_id}"

        controller = controller_for_id(controller_id)
        assert_controller_responds(controller, :find)
        if obj = controller.find(row_id)
          @agent.query_response(context, obj)
        else
          raise "No Object found for #{controller.class.name}:#{row_id}"
        end
      else
        # Class query
        controller_class = @controller_classes.values.find { |klass|
          klass.name == query.class_name
        }
        controller = controller_instance(context, controller_class)
        assert_controller_responds(controller, :list)
        if objs = controller.list
          objs.each do |obj|
            @agent.query_response(context, obj)
          end
        end
      end

    rescue Exception => ex
      @logger.error "Error in ovirt-agent: #{ex}"
      @logger.error "    " + ex.backtrace.join("\n    ")
    end

    # FIXME: How do you properly report errors for queries ?
    @agent.query_complete(context)
  end

  # This is called when an incoming method is requested of an object.
  def method_call(context, name, object_id, args, user_id)
    begin
      controller_id, row_id = @agent.decode_id(object_id)

      @logger.debug "Method: context=#{context} method=#{name} row_id=#{row_id}, args=#{args}"
      @logger.debug "User ID: #{user_id}"

      controller = controller_for_id(context, controller_id)
      assert_controller_responds(controller, name)

      controller.args = args
      controller.send(name)

      @agent.method_response(context, 0, "OK", args)
    rescue Exception => ex
      @logger.error "Error calling #{name}: #{ex}"
      @logger.error "    " + ex.backtrace.join("\n    ")
      @agent.method_response(context, 1, "ERROR: #{ex}", args)
    end
  end

  def controller_for_id(context, id)
    unless controller_class = @controller_classes[id]
      raise ControllerNotFoundError, "unknown controller id #{controller_id}"
    end
    controller_instance(context, controller_class)
  end

  def controller_instance(context, controller_class)
    controller_class.new(context, @agent, @logger)
  end

  def assert_controller_responds(controller, method)
    unless controller.respond_to?(name)
      raise ArgumentError, "unknown method #{name} for #{controller.class.name}"
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

    @controller_classes.values.each do |klass|
      klass.setup(@agent) if klass.respond_to?(:setup)
    end
    sleep
  end
end

if ARGV.size == 1
  broker = ARGV[0]
else
  broker = "localhost"
end
ovirt_agent = OvirtAgent.new(broker)
ovirt_agent.mainloop
