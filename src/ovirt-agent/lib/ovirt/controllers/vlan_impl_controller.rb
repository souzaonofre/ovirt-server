module Ovirt

  class VlanImplController < NetworkController

    def render(network)
      obj = Qmf::QmfObject.new(schema_class)
      obj['number'] = @network.number
      obj['network'] = @agent.encode_id(NetworkController.schema_class.id, @network.id)
      obj.set_object_id(encode_id(network.id))
      return obj
    end
  end
end
