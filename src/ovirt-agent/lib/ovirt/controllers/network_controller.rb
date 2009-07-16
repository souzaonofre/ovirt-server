module Ovirt

  class NetworkController < AgentController

    include NetworkService

    def find(id)
      svc_show(id)
      render(@network)
    end

    def list
      puts "query for Network class!"
      svc_list
      @networks.collect { |network| render(network) }
    end

    def render(network)
      obj = to_qmf(network, :propmap => { :proto => nil})
      obj['proto'] = network.boot_type.proto
      puts "network.type is #{@network.type}"
      if @network.type == 'PhysicalNetwork'
        obj['impl'] = @agent.encode_id(PhysicalNetworkImplController.schema_class.id, @network.id)
      elsif @network.type == 'Vlan'
        obj['impl'] = @agent.encode_id(VlanImplController.schema_class.id, @network.id)
      end
      return obj
    end
  end
end
