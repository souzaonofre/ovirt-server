#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.
require 'socket'

class VmController < ApplicationController
  include VmService

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :controller => 'dashboard' }

  def index
    svc_list(params)
    respond_to do |format|
      format.xml  { render :xml => @vms.to_xml(:include => :host) }
    end
  end

  def terminal
    # optionally add rows and columns params to url here
    # eg ?param=vmname&rows=30&columns=100
    @vm = Vm.find(params[:id])
    redirect_to "https://" + params[:host] +
                "/terminal/" + @vm.description +
                "/?param=" + @vm.description
  end

  def show
    svc_show(params[:id])
    @actions = @vm.get_action_hash(@user)
    render :layout => 'selection'
  end

  def add_to_smart_pool
    @pool = SmartPool.find(params[:smart_pool_id])
    render :layout => 'popup'
  end

  def new
    alert = svc_new(params[:vm_resource_pool_id])
    _setup_provisioning_options
    _setup_network_options
    @storage_tree = VmResourcePool.find(params[:vm_resource_pool_id]).get_hardware_pool.storage_tree.to_json
    render :layout => 'popup'
  end

  def create
    params[:vm][:forward_vnc] = params[:forward_vnc]
    _parse_network_params(params)
    alert = svc_create(params[:vm], params[:start_now], params[:nics])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  def edit
    svc_modify(params[:id])
    _setup_provisioning_options
    _setup_network_options
    @storage_tree = @vm.vm_resource_pool.get_hardware_pool.storage_tree(:vm_to_include => @vm).to_json
    render :layout => 'popup'
  end

  def update
    params[:vm][:forward_vnc] = params[:forward_vnc]
    _parse_network_params(params)
    alert = svc_update(params[:id], params[:vm], params[:start_now],
                       params[:restart_now], params[:nics])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  def delete
    vm_ids = params[:vm_ids].split(",")
    successes = []
    failures = {}
    vm_ids.each do |vm_id|
      begin
        svc_destroy(vm_id)
        successes << @vm
      # PermissionError expected
      rescue Exception => ex
        failures[@vm.nil? ? vm_id : @vm] = ex.message
      end
    end
    unless failures.empty?
      raise PartialSuccessError.new("Delete failed for some VMs",
                                    failures, successes)
    end
    render :json => { :object => "vm", :success => true,
                      :alert => "Virtual Machines were successfully deleted." }
  end

  def destroy
    alert = svc_destroy(params[:id])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  def storage_volumes_for_vm_json
    id = params[:id]
    vm_pool_id = params[:vm_pool_id]
    @vm = id ? Vm.find(id) : nil
    @vm_pool = vm_pool_id ? VmResourcePool.find(vm_pool_id) : nil

    json_list(StorageVolume.find_for_vm(@vm, @vm_pool),
              [:id, :display_name, :size_in_gb, :get_type_label])
  end

  def vm_action
    alert = svc_vm_action(params[:id], params[:vm_action],
                          params[:vm_action_data])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  def cancel_queued_tasks
    alert = svc_cancel_queued_tasks(params[:id])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  def migrate
    svc_get_for_migrate(params[:id])
    render :layout => 'popup'
  end

  def console
    svc_modify(params[:id])
    @show_vnc_error = "Console is unavailable for VM #{@vm.description}" unless @vm.has_console
    if @vm.host.hostname.match("priv\.ovirt\.org$")
      @vnc_hostname =  IPSocket.getaddress(@vm.host.hostname)
    else
      @vnc_hostname =  @vm.host.hostname
    end
    render :layout => false
  end

  protected
  def _setup_provisioning_options
    @provisioning_options = [[Vm::PXE_OPTION_LABEL, Vm::PXE_OPTION_VALUE],
                             [Vm::HD_OPTION_LABEL, Vm::HD_OPTION_VALUE]]

    begin
      @provisioning_options += Cobbler::Image.find.collect do |image|
        [image.name + Vm::COBBLER_IMAGE_SUFFIX,
          "#{Vm::IMAGE_PREFIX}@#{Vm::COBBLER_PREFIX}#{Vm::PROVISIONING_DELIMITER}#{image.name}"]
      end

      @provisioning_options += Cobbler::Profile.find.collect do |profile|
        [profile.name + Vm::COBBLER_PROFILE_SUFFIX,
          "#{Vm::PROFILE_PREFIX}@#{Vm::COBBLER_PREFIX}#{Vm::PROVISIONING_DELIMITER}#{profile.name}"]

    end
    rescue
      #if cobbler doesn't respond/is misconfigured/etc just don't add profiles
    end
  end

  # sets up a list of nics for the vm form
  def _setup_network_options
    net_conditions = ""
    @nics = []

    unless @vm.nil?
      @vm.nics.each { |nic|
         nnic = Nic.new(:mac => nic.mac,
                        :vm_id => @vm.id,
                        :network => nic.network)

         if(nic.network.boot_type.proto == 'static')
           nnic.ip_addresses << IpAddress.new(:address => nic.ip_address)
         end
         @nics.push nnic

         net_conditions += (net_conditions == "" ? "" : " AND ") +
                           "id != " + nic.network_id.to_s
      }
    end

    networks = Network.find(:all, :conditions => net_conditions)

    networks.each{ |net|
        nnic = Nic.new(:mac => Nic::gen_mac, :network => net)
        if(net.boot_type.proto == 'static')
           nnic.ip_addresses << IpAddress.new(:address => '127.0.0.1') # FIXME
        end
        @nics.push nnic
    }

  end

  # merges vm / network parameters as submitted on the vm form
  def _parse_network_params(params)
     # 'params' subarrays 'networks', 'macs', and 'ip_addresses' all
     # correspond to each other such that networks[i] corresponds
     # to macs[i] and networks.static_networks_subset[j] corresponds
     # to ip_addresses[j]
     ip_counter = 0
     params[:vm][:nics] = []
     params[:nics] = []

     unless params[:networks].nil?
       (0...params[:networks].length).each { |i|

          network_id = params[:networks][i]
          unless network_id.nil? || network_id == ""
             nic = { :mac => params[:macs][i],
                     :network_id => network_id, :bandwidth => 0 }

             if(Network.find(network_id).boot_type.proto == 'static')
                # FIXME make this able to be v4 or v6 address
                nic[:ip_addresses] = [IpV4Address.new({ :address => params[:ip_addresses][ip_counter] })]
                ip_counter += 1
             end

             params[:nics].push(nic)
          end

       }
    end
  end

end
