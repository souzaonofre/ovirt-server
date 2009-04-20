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
require 'services/vm_service'

class VmController < ApplicationController
  include VmService

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :controller => 'dashboard' }

  before_filter :pre_console, :only => [:console]

  def index
    @vms = Vm.find(:all,
                   :include => [{:vm_resource_pool =>
                                  {:permissions => {:role => :privileges}}}],
                   :conditions => ["privileges.name=:priv
                               and permissions.uid=:user",
                             { :user => get_login_user, :priv => Privilege::VIEW }])
      respond_to do |format|
          format.xml  { render :xml => @vms.to_xml(:include => :host) }
      end
  end

  def show
    begin
      svc_show(params[:id])
      @actions = @vm.get_action_hash(@user)
      render :layout => 'selection'
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
    end
  end

  def add_to_smart_pool
    @pool = SmartPool.find(params[:smart_pool_id])
    render :layout => 'popup'
  end

  def new
    @storage_tree = VmResourcePool.find(params[:vm_resource_pool_id]).get_hardware_pool.storage_tree.to_json
    render :layout => 'popup'
  end

  def create
    params[:vm][:forward_vnc] = params[:forward_vnc]
    begin
      alert = svc_create(params[:vm], params[:start_now])
      render :json => { :object => "vm", :success => true, :alert => alert  }
    rescue PermissionError => perm_error
      handle_auth_error(perm_error.message)
    rescue Exception => error
      json_error("vm", @vm, error)
    end
  end

  def edit
    @storage_tree = @vm.vm_resource_pool.get_hardware_pool.storage_tree(:vm_to_include => @vm).to_json
    render :layout => 'popup'
  end

  def update
    params[:vm][:forward_vnc] = params[:forward_vnc]
    begin
      alert = svc_update(params[:id], params[:vm], params[:start_now],
                         params[:restart_now])
      render :json => { :object => "vm", :success => true, :alert => alert  }
    rescue Exception => error
      # FIXME: need to distinguish vm vs. task save errors (but should mostly be vm)
      json_error("vm", @vm, error)
    end
  end

  #FIXME: we need permissions checks. user must have permission. Also state checks
  # this should probably be implemented as an action on the containing VM pool once
  # that service module is defined
  def delete
    vm_ids_str = params[:vm_ids]
    vm_ids = vm_ids_str.split(",").collect {|x| x.to_i}
    failure_list = []
    success = false
    begin
      Vm.transaction do
        vms = Vm.find(:all, :conditions => "id in (#{vm_ids.join(', ')})")
        vms.each do |vm|
          if vm.is_destroyable?
            destroy_cobbler_system(vm)
            vm.destroy
          else
            failure_list << vm.description
          end
        end
      end
      if failure_list.empty?
        success = true
        alert = "Virtual Machines were successfully deleted."
      else
        alert = "The following Virtual Machines were not deleted (a VM must be stopped to delete it): "
        alert+= failure_list.join(', ')
      end
    rescue
      alert = "Error deleting virtual machines."
    end
    render :json => { :object => "vm", :success => success, :alert => alert }
  end

  def destroy
    begin
      alert = svc_destroy(params[:id])
      render :json => { :object => "vm", :success => true, :alert => alert  }
    rescue ActionError => error
      json_error("vm", @vm, error)
    rescue Exception => error
      json_error("vm", @vm, error)
    end
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
    begin
      alert = svc_vm_action(params[:id], params[:vm_action],
                            params[:vm_action_data])
      render :json => { :object => "vm", :success => true, :alert => alert  }
    rescue ActionError => error
      json_error("vm", @vm, error)
    rescue Exception => error
      json_error("vm", @vm, error)
    end
  end

  def cancel_queued_tasks
    begin
      alert = svc_cancel_queued_tasks(params[:id])
      render :json => { :object => "vm", :success => true, :alert => alert  }
    rescue Exception => error
      json_error("vm", @vm, error)
    end
  end

  def migrate
    @vm = Vm.find(params[:id])
    @current_pool_id=@vm.vm_resource_pool.id
    set_perms(@vm.get_hardware_pool)
    authorize_admin
    render :layout => 'popup'
  end

  def console
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

  def pre_new
    unless params[:vm_resource_pool_id]
      flash[:notice] = "VM Resource Pool is required."
      redirect_to :controller => 'dashboard'
    end

    # random MAC
    mac = [ 0x00, 0x16, 0x3e, rand(0x7f), rand(0xff), rand(0xff) ]
    # random uuid
    uuid = ["%02x" * 4, "%02x" * 2, "%02x" * 2, "%02x" * 2, "%02x" * 6].join("-") %
      Array.new(16) {|x| rand(0xff) }
    newargs = {
      :vm_resource_pool_id => params[:vm_resource_pool_id],
      :vnic_mac_addr => mac.collect {|x| "%02x" % x}.join(":"),
      :uuid => uuid
    }
    @vm = Vm.new( newargs )
    unless params[:vm_resource_pool_id]
      @vm.vm_resource_pool = @vm_resource_pool
    end
    set_perms(@vm.vm_resource_pool)
    @networks = Network.find(:all).collect{ |net| [net.name, net.id] }
    _setup_provisioning_options
  end
  def pre_edit
    @vm = Vm.find(params[:id])
    set_perms(@vm.vm_resource_pool)
    @networks = Network.find(:all).collect{ |net| [net.name, net.id] }
    _setup_provisioning_options
  end
  def pre_console
    pre_edit
    authorize_user
  end
  # FIXME: remove these when service transition is complete. these are here
  # to keep from running permissions checks and other setup steps twice
  def tmp_pre_update
  end
  def tmp_authorize_admin
  end

end
