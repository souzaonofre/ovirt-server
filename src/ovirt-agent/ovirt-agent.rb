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
require 'ovirt/agent_controller'
require 'ovirt/controllers/ovirt_controller'
require 'ovirt/controllers/vmdef_controller'


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

  def properties
    unless @properties
      @properties = []
      impl.getPropertyCount.times do |i|
        @properties << impl.getProperty(i)
      end
    end
    @properties
  end
end

class Qmf::SchemaProperty
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



class OvirtAgent < Qmf::AgentHandler

  include Ovirt::SchemaParser

  def initialize(host)

    ensure_credentials

    # FIXME: Use RAILS_DEFAULT_LOGGER
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
        controller_id, row_id = @agent.decode_id(query.object_id)

        @logger.debug "Query: object_num=#{controller_id}:#{row_id}"

        controller = controller_for_id(context, controller_id, user_id)
        assert_controller_responds(controller, :find)
        if obj = controller.find(row_id)
          @agent.query_response(context, obj)
        else
          raise "No Object found for #{controller.class.name}:#{row_id}"
        end
      else
        # Class query
        controller_class = @controller_classes.values.find { |klass|
          klass.schema_class.name == query.class_name
        }
        unless controller_class
          raise "Unknown class #{query.class_name}"
        end
        controller = controller_instance(context, controller_class, user_id)
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

      controller = controller_for_id(context, controller_id, user_id)
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

  def controller_for_id(context, id, user_id)
    unless controller_class = @controller_classes[id]
      raise ControllerNotFoundError, "unknown controller id #{controller_id}"
    end
    controller_instance(context, controller_class, user_id)
  end

  def controller_instance(context, controller_class, user_id)
    controller_class.new(context, @agent, @logger, user_id)
  end

  def assert_controller_responds(controller, method)
    unless controller.respond_to?(method)
      raise ArgumentError, "unknown method #{method} for #{controller.class.name}"
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
