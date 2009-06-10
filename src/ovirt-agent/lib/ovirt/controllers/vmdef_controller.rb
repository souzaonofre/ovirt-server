class VmDefController < AgentController

  include VmService

  def find(id)
    svc_show(id)
    render(@vm)
  end

  def list
    puts "query for VmDef class!"
    # Return all VmDef objects. FIXME: Use VmService to list vm's
    Vm.find(:all).collect { |vm| render(vm) }
  end

  def render(vm)
    to_qmf(vm, :propmap => { :mac => :vnic_mac_addr } )
  end
end

