
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

  def initialize(context, agent, logger, user_id)
    @context = context
    @agent = agent
    @logger = logger
    @user_id = user_id
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

  # Produce a QMF object of class +schema_class+ from obj; only properties
  # for which +obj+ has accessors are set.
  #
  # Properties can be explicitly mapped to attributes by passing in a map
  # from property names (symbols) to attribute names as the +:propmap+
  # argument
  def to_qmf(obj, kwargs = {})
    qmf = Qmf::QmfObject.new(schema_class)
    propmap = kwargs[:propmap] || {}
    schema_class.properties.collect { |p| p.name.to_sym }.each { |n|
      a = propmap[n] || n
      puts "Property translation - qmfobject[#{n}] = activerecord[#{a}]"
      qmf[n] = obj.send(a) if obj.respond_to?(a)
    }

    qmf.set_object_id(encode_id(obj.id))

    return qmf
  end

  # Subclasses should have
  #
  #   find(id) : look up object with that id and return the QMF object
  #   list     : return list of all QMF objects
  #
  #   methods with the same name as defined in the schema
  #     arguments can be accessed through method 'args'
end


