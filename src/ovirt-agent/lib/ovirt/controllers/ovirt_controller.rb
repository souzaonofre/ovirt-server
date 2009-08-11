module Ovirt
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

    def create_vlan_network
      extend NetworkService

      boot_type = BootType.find(:first, :conditions => ["proto = ?", args['proto']])
      raise "Unknown boot protocol #{args['proto']}." if not boot_type
      puts "in create_vlan_network, boot_type id is #{boot_type.id}"
      hash = { :name => args['name'], :number => args['number'], :type => 'Vlan', :boot_type_id => boot_type.id }

      svc_create(hash)

      args['network'] = @agent.encode_id(NetworkController.schema_class.id, @network.id)
    end

    def create_physical_network
      extend NetworkService

      boot_type = BootType.find(:first, :conditions => ["proto = ?", args['proto']])
      raise "Unknown boot protocol #{args['proto']}." if not boot_type
      puts "in create_physical_network, boot_type id is #{boot_type.id}"
      hash = { :name => args['name'], :type => 'PhysicalNetwork', :boot_type_id => boot_type.id }

      svc_create(hash)

      args['network'] = @agent.encode_id(NetworkController.schema_class.id, @network.id)
    end
  end
end

