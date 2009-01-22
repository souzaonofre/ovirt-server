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
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :controller => 'dashboard' }

  before_filter :pre_vm_action, :only => [:vm_action, :cancel_queued_tasks, :console]

  def index
      roles = "('" +
          Permission::roles_for_privilege(Permission::PRIV_VIEW).join("', '") +
          "')"
      user = get_login_user
      @vms = Vm.find(:all,
         :joins => "join permissions p on (vm_resource_pool_id = p.pool_id)",
         :conditions => [ "p.uid = :user and p.user_role in #{roles}",
                          { :user => user }])
      respond_to do |format|
          format.xml  { render :xml => @vms.to_xml(:include => :host) }
      end
  end

  def show
    set_perms(@perm_obj)
    @actions = @vm.get_action_hash(@user)
    unless @can_view
      flash[:notice] = 'You do not have permission to view this vm: redirecting to top level'
      redirect_to :controller => 'resources', :controller => 'dashboard'
    end
    render :layout => 'selection'
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
    begin
      Vm.transaction do
        @vm.save!
        _setup_vm_provision(params)
        @task = VmTask.new({ :user        => @user,
                             :task_target => @vm,
                             :action      => VmTask::ACTION_CREATE_VM,
                             :state       => Task::STATE_QUEUED})
        @task.save!
      end
      start_now = params[:start_now]
      if (start_now)
        if @vm.get_action_list.include?(VmTask::ACTION_START_VM)
          @task = VmTask.new({ :user        => @user,
                               :task_target => @vm,
                               :action      => VmTask::ACTION_START_VM,
                               :state       => Task::STATE_QUEUED})
          @task.save!
          alert = "VM was successfully created. VM Start action queued."
        else
          alert = "VM was successfully created. Resources are not available to start VM now."
        end
      else
        alert = "VM was successfully created."
      end
      render :json => { :object => "vm", :success => true, :alert => alert  }
    rescue Exception => error
      # FIXME: need to distinguish vm vs. task save errors (but should mostly be vm)
      render :json => { :object => "vm", :success => false,
                        :errors => @vm.errors.localize_error_messages.to_a }
    end

  end

  def edit
    @storage_tree = @vm.vm_resource_pool.get_hardware_pool.storage_tree(:vm_to_include => @vm).to_json
    render :layout => 'popup'
  end

  def update
    begin
      #needs restart if certain fields are changed (since those will only take effect the next startup)
      needs_restart = false
      unless @vm.get_pending_state == Vm::STATE_STOPPED
        Vm::NEEDS_RESTART_FIELDS.each do |field|
          unless @vm[field].to_s == params[:vm][field]
            needs_restart = true
            break
          end
        end
        current_storage_ids = @vm.storage_volume_ids.sort
        new_storage_ids = params[:vm][:storage_volume_ids]
        new_storage_ids = [] unless new_storage_ids
        new_storage_ids = new_storage_ids.sort.collect {|x| x.to_i }
        needs_restart = true unless current_storage_ids == new_storage_ids
      end
      params[:vm][:needs_restart] = 1 if needs_restart
      @vm.update_attributes!(params[:vm])
      _setup_vm_provision(params)

      if (params[:start_now] and @vm.get_action_list.include?(VmTask::ACTION_START_VM) )
        @task = VmTask.new({ :user        => @user,
                             :task_target => @vm,
                             :action      => VmTask::ACTION_START_VM,
                             :state       => Task::STATE_QUEUED})
        @task.save!
      elsif ( params[:restart_now] and @vm.get_action_list.include?(VmTask::ACTION_SHUTDOWN_VM) )
        @task = VmTask.new({ :user        => @user,
                             :task_target => @vm,
                             :action      => VmTask::ACTION_SHUTDOWN_VM,
                             :state       => Task::STATE_QUEUED})
        @task.save!
        @task = VmTask.new({ :user    => @user,
                             :task_target => @vm,
                             :action  => VmTask::ACTION_START_VM,
                             :state   => Task::STATE_QUEUED})
        @task.save!
      end


      render :json => { :object => "vm", :success => true,
                        :alert => 'Vm was successfully updated.'  }
    rescue
      # FIXME: need to distinguish vm vs. task save errors (but should mostly be vm)
      render :json => { :object => "vm", :success => false,
                        :errors => @vm.errors.localize_error_messages.to_a }
    end
  end

  #FIXME: we need permissions checks. user must have permission. Also state checks
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
    vm_resource_pool = @vm.vm_resource_pool_id
    if (@vm.is_destroyable?)
      destroy_cobbler_system(@vm)
      @vm.destroy
      render :json => { :object => "vm", :success => true,
        :alert => "Virtual Machine was successfully deleted." }
    else
      render :json => { :object => "vm", :success => false,
        :alert => "Vm must be stopped to delete it." }
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
    vm_action = params[:vm_action]
    data = params[:vm_action_data]
    begin
      if @vm.queue_action(get_login_user, vm_action, data)
        render :json => { :object => "vm", :success => true, :alert => "#{vm_action} was successfully queued." }
      else
        render :json => { :object => "vm", :success => false, :alert => "#{vm_action} is an invalid action." }
      end
    rescue
      render :json => { :object => "vm", :success => false, :alert => "Error in queueing #{vm_action}." }
    end
  end

  def cancel_queued_tasks
    begin
      Task.transaction do
        @vm.tasks.queued.each { |task| task.cancel}
      end
      render :json => { :object => "vm", :success => true, :alert => "queued tasks were canceled." }
    rescue
      render :json => { :object => "vm", :success => true, :alert => "queued tasks cancel failed." }
    end
  end

  def migrate
    @vm = Vm.find(params[:id])
    @perm_obj = @vm.get_hardware_pool
    @redir_obj = @vm
    @current_pool_id=@vm.vm_resource_pool.id
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

  # FIXME: move this to an edit_vm task in taskomatic
  def _setup_vm_provision(params)
    # spaces are invalid in the cobbler name
    name = params[:vm][:uuid]
    mac = params[:vm][:vnic_mac_addr]
    provision = params[:vm][:provisioning_and_boot_settings]
    # determine what type of provisioning was selected for the VM
    provisioning_type = :pxe_or_hd_type
    provisioning_type = :image_type  if provision.index "#{Vm::IMAGE_PREFIX}@#{Vm::COBBLER_PREFIX}"
    provisioning_type = :system_type if provision.index "#{Vm::PROFILE_PREFIX}@#{Vm::COBBLER_PREFIX}"

    unless provisioning_type == :pxe_or_hd_type
      cobbler_name = provision.slice(/(.*):(.*)/, 2)
      system = Cobbler::System.find_one(name)
      unless system
        nic = Cobbler::NetworkInterface.new({'mac_address' => mac})

        case provisioning_type
        when :image_type:
            system = Cobbler::System.new("name" => name, "image"    => cobbler_name)
        when :system_type:
            system = Cobbler::System.new("name" => name, "profile" => cobbler_name)
        end

        system.interfaces = [nic]
        system.save
      end
    end
  end

  def pre_new
    # if no vm_resource_pool is passed in, find (or auto-create) it based on hardware_pool_id
    unless params[:vm_resource_pool_id]
      unless params[:hardware_pool_id]
        flash[:notice] = "VM Resource Pool or Hardware Pool is required."
        redirect_to :controller => 'dashboard'
      end
      @hardware_pool = HardwarePool.find(params[:hardware_pool_id])
      @user = get_login_user
      vm_resource_pool = @hardware_pool.sub_vm_resource_pools.select {|pool| pool.name == @user}.first
      if vm_resource_pool
        params[:vm_resource_pool_id] = vm_resource_pool.id
      else
        @vm_resource_pool = VmResourcePool.new({:name => vm_resource_pool})
        @vm_resource_pool.tmp_parent = @hardware_pool
        @vm_resource_pool_name = @user
      end
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
    @perm_obj = @vm.vm_resource_pool
    @current_pool_id=@perm_obj.id
    _setup_provisioning_options
  end
  def pre_create
    params[:vm][:state] = Vm::STATE_PENDING
    vm_resource_pool_name = params[:vm_resource_pool_name]
    hardware_pool_id = params[:hardware_pool_id]
    if vm_resource_pool_name and hardware_pool_id
      hardware_pool = HardwarePool.find(hardware_pool_id)
      vm_resource_pool = VmResourcePool.new({:name => vm_resource_pool_name})
      vm_resource_pool.create_with_parent(hardware_pool)
      params[:vm][:vm_resource_pool_id] = vm_resource_pool.id
    end
    @vm = Vm.new(params[:vm])
    @perm_obj = @vm.vm_resource_pool
    @current_pool_id=@perm_obj.id
  end
  def pre_show
    @vm = Vm.find(params[:id])
    @perm_obj = @vm.vm_resource_pool
    @current_pool_id=@perm_obj.id
  end
  def pre_edit
    @vm = Vm.find(params[:id])
    @perm_obj = @vm.vm_resource_pool
    @current_pool_id=@perm_obj.id
    _setup_provisioning_options
  end
  def pre_vm_action
    pre_edit
    authorize_user
  end

  private

  def destroy_cobbler_system(vm)
    # Destroy the Cobbler system first if it's defined
    if vm.uses_cobbler?
      system = Cobbler::System.find_one(vm.cobbler_system_name)
      system.remove if system
    end
  end
end
