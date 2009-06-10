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

end

