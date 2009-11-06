#!/usr/bin/ruby
#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Chris Lalancette <clalance@redhat.com> and
# Ian Main <imain@redhat.com>
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

$: << File.join(File.dirname(__FILE__), "../dutils")
$: << File.join(File.dirname(__FILE__), ".")

require 'rubygems'
require 'qmf'
require 'monitor'
require 'dutils'
require 'optparse'
require 'daemons'
require 'logger'
include Daemonize

require 'task_vm'
require 'task_storage'

# This sad and pathetic readjustment to ruby logger class is
# required to fix the formatting because rails does the same
# thing but overrides it to just the message.
#
# See eg: http://osdir.com/ml/lang.ruby.rails.core/2007-01/msg00082.html
#
class Logger
  def format_message(severity, timestamp, progname, msg)
    "#{severity} #{timestamp} (#{$$}) #{msg}\n"
  end
end


class TaskOmatic

  include MonitorMixin

  $logfile = '/var/log/ovirt-server/taskomatic.log'

  def initialize()
    super()

    @sleeptime = 2
    @nth_host = 0

    do_daemon = true
    do_debug = false

    opts = OptionParser.new do |opts|
      opts.on("-h", "--help", "Print help message") do
        puts opts
        exit
      end
      opts.on("-n", "--nodaemon", "Run interactively (useful for debugging)") do |n|
        do_daemon = false
      end
      opts.on("-d", "--debug", "Print verbose debugging output") do |d|
        do_debug = true
      end
      opts.on("-s N", Integer, "--sleep",
              "Seconds to sleep between iterations (default is 5 seconds)") do |s|
        sleeptime = s
      end
    end
    begin
      opts.parse!(ARGV)
    rescue OptionParser::InvalidOption
      puts opts
      exit
    end

    if do_daemon
      # This gets around a problem with paths for the database stuff.
      # Normally daemonize would chdir to / but the paths for the database
      # stuff are relative so it breaks it.. It's either this or rearrange
      # things so the db stuff is included after daemonizing.
      pwd = Dir.pwd
      daemonize
      Dir.chdir(pwd)
      @logger = Logger.new($logfile)
    else
      @logger = Logger.new(STDERR)
    end

    #@logger.level = Logger::DEBUG if do_debug
    #
    # For now I'm going to always enable debugging until we do a real release.
    @logger.level = Logger::DEBUG

    ensure_credentials

    server, port = nil
    sleepy = 5
    while true do
      server, port = get_srv('qpidd', 'tcp')
      break if server
      @logger.error "Unable to determine qpid server from DNS SRV record, retrying.." if not server
      sleep(sleepy)
      sleepy *= 2 if sleepy < 120
    end

    settings = Qmf::ConnectionSettings.new
    settings.host = server
    settings.port = port
    settings.sendUserId = false

    @connection = Qmf::Connection.new(settings)
    @qmfc = Qmf::Console.new
    @broker = @qmfc.add_connection(@connection)
    @broker.wait_for_stable
  end

  def ensure_credentials()
    get_credentials('qpidd')
    get_credentials('libvirt')

    Thread.new do
      while true do
        sleep(3600)
        get_credentials('qpidd')
        get_credentials('libvirt')
      end
    end
  end

  def find_capable_host(db_vm)
    possible_hosts = []

    # FIXME: There may be a bug here in that a host that's already running the
    # vm won't be returned.  I think that's supposed to be for migration
    # but it could break creation of VMs in certain conditions..

    vm = @qmfc.object(:class => "domain", 'uuid' => db_vm.uuid)

    db_vm.vm_resource_pool.get_hardware_pool.hosts.each do |curr|
      # Now each of 'curr' is in the right hardware pool..
      # now we check them out.

      node = @qmfc.object(:class => "node", 'hostname' => curr.hostname)
      next unless node

      # So now we expect if the node was found it's alive and well, then
      # we check to make sure there's enough real cores for the number of
      # vcpus, the node memory is adequate, the node is not disabled in the
      # database, and if the node id is nil or if it is already running
      # (has a node id set) then it is probably looking to migrate so we
      # find a node that is not the current node.
      #
      # In the future we could add load or similar checks here.

      #puts "checking node, #{node.cores} >= #{db_vm.num_vcpus_allocated},"
      #puts "and #{node.memory} >= #{db_vm.memory_allocated}"
      #puts "and not #{curr.is_disabled.nil?} and #{curr.is_disabled == 0}"
      #puts "and #{vm ? vm : 'nil'} or #{vm ? vm.active : 'nil'}) or #{vm ? vm.node : 'nil'} != #{node.object_id}"

      if node and node.cores >= db_vm.num_vcpus_allocated \
         and node.memory >= db_vm.memory_allocated \
         and not curr.is_disabled.nil? and curr.is_disabled == 0 \
         and ((!vm or vm.active == 'false') or vm.node != node.object_id)
         # FIXME ensure host is on all networks a vm's assigned to
         # db_vm.nics.each { |nic| ignore if nic.network ! in host }
        possible_hosts.push(curr)
      end
    end

    #puts "possible_hosts.length = #{possible_hosts.length}"
    if possible_hosts.length == 0
      # we couldn't find a host that matches this criteria
      raise "No host matching VM parameters could be found"
    end

    # Right now we're just picking the nth host, we could also look at
    # how many vms are already on it, or the load of the hosts etc.
    host = possible_hosts[@nth_host % possible_hosts.length]
    @nth_host += 1

    return host
  end

  def connect_storage_pools(node, storage_volumes)
    storagedevs = []
    storage_volumes.each do |db_volume|
      # here, we need to iterate through each volume and possibly attach it
      # to the host we are going to be using
      db_pool = db_volume.storage_pool
      if db_pool == nil
        # Hum.  Specified by the VM description, but not in the storage pool?
        # continue on and hope for the best
        @logger.error "Couldn't find pool for volume #{db_volume.path}; skipping"
        next
      end

      # we have to special case LVM pools.  In that case, we need to first
      # activate the underlying physical device, and then do the logical one
      if db_volume[:type] == "LvmStorageVolume"
        phys_libvirt_pool = get_libvirt_lvm_pool_from_volume(db_volume, @logger)
        phys_libvirt_pool.connect(@qmfc, node)
      end

      @logger.debug "Verifying mount of pool #{db_pool.ip_addr}:#{db_pool.type}:#{db_pool.target}:#{db_pool.export_path}"
      libvirt_pool = LibvirtPool.factory(db_pool, @logger)
      libvirt_pool.connect(@qmfc, node)

      # OK, the pool should be all set.  The last thing we need to do is get
      # the path based on the volume key

      volume_key = db_volume.key
      pool = libvirt_pool.remote_pool

      @logger.debug "Pool mounted: #{pool.name}; state: #{pool.state}"

      volume = @qmfc.object(:class => 'volume',
                            'key' => volume_key,
                            'storagePool' => pool.object_id)
      if volume == nil
        @logger.info "Unable to find volume by key #{volume_key} attached to pool #{pool.name}, trying by filename..."
        volume = @qmfc.object(:class => 'volume',
                              'name' => db_volume.filename,
                              'storagePool' => pool.object_id)
	raise "Unable to find volume by key (#{volume_key}) or filename (#{db_volume.filename}), giving up." unless volume
      end
      @logger.debug "Verified volume of pool #{volume.path}"

      storagedevs << volume.path
    end

    return storagedevs
  end

  def task_create_vm(task)
    @logger.info "starting task_create_vm"
    # This is mostly just a place holder.
    vm = find_vm(task, false)
    if vm.state != Vm::STATE_PENDING
      raise "VM not pending"
    end
    vm.state = Vm::STATE_STOPPED
    vm.save!
  end

  def teardown_storage_pools(node)

    # This is rather silly because we only destroy pools if there are no
    # more vms on the node.  We should be reference counting the pools
    # somehow so we know when they are no longer in use.
    vms = @qmfc.objects(:class => 'domain', 'node' => node.object_id)
    if vms.length > 0
      return
    end
    pools = @qmfc.objects(:class => 'pool', 'node' => node.object_id)

    # We do this in two passes, first undefine/destroys LVM pools, then
    # we do physical pools.
    pools.each do |pool|
      # libvirt-qpid sets parentVolume to the name of the parent volume
      # if this is an LVM pool, else it leaves it empty.
      if pool.parentVolume != ''
        result = pool.destroy(:timeout => 60 * 2)
        result = pool.undefine(:timeout => 60 * 2)
      end
    end

    pools.each do |pool|
      result = pool.destroy(:timeout => 60 * 2)
      result = pool.undefine(:timeout => 60 * 2)
    end
  end


  def task_shutdown_or_destroy_vm(task, action)
    @logger.info "starting task_shutdown_or_destroy_vm"
    db_vm = task.vm
    vm = @qmfc.object(:class => 'domain', 'uuid' => db_vm.uuid)
    if !vm
      @logger.error "VM already shut down?"
      return
    end

    node = @qmfc.object(:object_id => vm.node)
    raise "Unable to get node that vm is on??" unless node

    if vm.state == "shutdown" or vm.state == "shutoff"
      result = vm.undefine
      if result.status == 0
        @logger.info "Deleted VM #{db_vm.description}."
        teardown_storage_pools(node)
      end
      return
    elsif vm.state == "suspended"
      raise "Cannot shutdown suspended domain"
    elsif vm.state == "saved"
      raise "Cannot shutdown saved domain"
    end

    if action == :shutdown
      result = vm.shutdown
      @logger.info "shutdown - result.status is #{result.status}"
      raise "Error shutting down VM: #{result.text}" unless result.status == 0
    elsif action == :destroy
      result = vm.destroy
      @logger.info "destroy - result.status is #{result.status}"
      raise "Error destroying VM: #{result.text}" unless result.status == 0
    end

    # undefine can fail, for instance, if we live migrated from A -> B, and
    # then we are shutting down the VM on B (because it only has "transient"
    # XML).  Therefore, just ignore undefine errors so we do the rest
    # FIXME: we really should have a marker in the database somehow so that
    # we can tell if this domain was migrated; that way, we can tell the
    # difference between a real undefine failure and one because of migration
    #
    # We only set the vm to shutdown if the undefine succeeds.  Otherwise,
    # dbomatic will pick up any state changes.  doing a 'shutdown' rather
    # than destroy for instance can possibly take quite some time.
    result = vm.undefine
    if result.status == 0
        @logger.info "Deleted VM #{db_vm.description}."
        set_vm_shut_down(db_vm)
        teardown_storage_pools(node)
    else
        @logger.info "Error undefining VM: #{result.text}" unless result.status == 0
    end
  end

  def task_start_vm(task)
    @logger.info "starting task_start_vm"
    db_vm = find_vm(task, false)

    vm = @qmfc.object(:class => "domain", 'uuid' => db_vm.uuid)

    if vm
      case vm.state
        when "running"
          return
        when "blocked"
          raise "Virtual machine state is blocked, cannot start VM."
        when "paused"
          raise "Virtual machine is currently paused, cannot start, must resume."
      end
    end
    db_host = find_capable_host(db_vm)

    node = @qmfc.object(:class => "node", 'hostname' => db_host.hostname)

    raise "Unable to find host #{db_host.hostname} to create VM on." unless node
    @logger.info("VM will be started on node #{node.hostname}")

    image_volume = task_storage_cobbler_setup(db_vm)

    # FIXME: I know this part is broken..
    #
    # hrrm, who wrote this comment and why is it broken?  - Ian
    volumes = []
    volumes += db_vm.storage_volumes
    volumes << image_volume if image_volume

    @logger.debug("Connecting volumes: #{volumes}")
    storagedevs = connect_storage_pools(node, volumes)

    # loop through each nic/network assigned to vm,
    #  finding necessary host devices to bridge
    net_interfaces = []
    db_vm.nics.each { |nic|
       device = net_device = nil
       if nic.network.class == PhysicalNetwork
         device = Nic.find(:first,
               :conditions => ["host_id = ? AND network_id = ?",
                                    db_host.id, nic.network_id ])
       else
         device = Bonding.find(:first,
               :conditions => ["host_id = ? AND vlan_id = ?",
                                    db_host.id, nic.network_id ])
       end

       unless device.nil?
          net_device = "br" + device.interface_name
       else
          net_device = "breth0" # FIXME remove this default at some point
       end
       net_interfaces.push({ :mac => nic.mac, :interface => net_device })
    }

    xml = create_vm_xml(db_vm.description, db_vm.uuid, db_vm.memory_allocated,
              db_vm.memory_used, db_vm.num_vcpus_allocated, db_vm.boot_device,
              net_interfaces, storagedevs)

    @logger.debug("XML Domain definition: #{xml}")

    result = node.domainDefineXML(xml.to_s)
    raise "Error defining virtual machine: #{result.text}" unless result.status == 0

    domain = @qmfc.object(:object_id => result.domain)
    raise "Cannot find domain on host #{db_host.hostname}, cannot start virtual machine." unless domain

    result = domain.create
    if result.status != 0
      domain.undefine
      raise "Error creating virtual machine: #{result.text}"
    end

    result = domain.getXMLDesc

    # Reget the db record or you can get 'dirty' errors.  This can happen in a number
    # of places so you'll see a lot of .reloads.
    db_vm.reload
    set_vm_vnc_port(db_vm, result.description) unless result.status != 0

    # This information is not available via the libvirt interface.
    db_vm.memory_used = db_vm.memory_allocated
    db_vm.boot_device = Vm::BOOT_DEV_HD
    db_vm.host_id = db_host.id
    db_vm.save!

    # We write the new state here even though dbomatic will set it soon anyway.
    # This is just to let the UI know that it's good to go right away and really
    # dbomatic will just write the same thing over top of it soon enough.
    db_vm.state = Vm::STATE_RUNNING
    db_vm.save!
  end

  def task_suspend_vm(task)
    @logger.info "starting task_suspend_vm"
    db_vm = task.vm
    dom = @qmfc.object(:class => 'domain', 'uuid' => db_vm.uuid)
    raise "Unable to locate VM to suspend" unless dom

    if dom.state != "running" and dom.state != "blocked"
      raise "Cannot suspend domain in state #{dom.state}"
    end

    result = dom.suspend
    raise "Error suspending VM: #{result.text}" unless result.status == 0

    db_vm.reload
    db_vm.state = Vm::STATE_SUSPENDED
    db_vm.save!
  end

  def task_resume_vm(task)
    @logger.info "starting task_resume_vm"
    db_vm = task.vm
    dom = @qmfc.object(:class => 'domain', 'uuid' => db_vm.uuid)
    raise "Unable to locate VM to resume" unless dom

    if dom.state == "running"
      # the VM is already suspended; just return success
      return
    elsif dom.state != "paused"
      raise "Cannot suspend domain in state #{dom.state}"
    end

    result = dom.resume
    raise "Error resuming VM: #{result.text}" unless result.status == 0

    db_vm.reload
    db_vm.state = Vm::STATE_RUNNING
    db_vm.save!
  end

  def task_save_vm(task)
    @logger.info "starting task_save_vm"

    # FIXME: This task is actually very broken.  It saves to a local
    # disk on the node which could be volatile memory, and there is no
    # differentiation of a 'saved' vm in libvirt which makes it so we
    # really have no way of knowing when a domain is 'saved'.  We
    # need to put it on the storage server and mark it in the database
    # where the image is stored.
    db_vm = task.vm
    dom = @qmfc.object(:class => 'domain', 'uuid' => db_vm.uuid)
    raise "Unable to locate VM to save" unless dom

    filename = "/tmp/#{dom.uuid}.save"
    @logger.info "saving vm #{dom.name} to #{filename}"
    result = dom.save(filename)
    raise "Error saving VM: #{result.text}" unless result.status == 0

    db_vm.reload
    set_vm_state(db_vm, Vm::STATE_SAVED)
  end

  def task_restore_vm(task)
    @logger.info "starting task_restore_vm"

    # FIXME: This is also broken, see task_save_vm FIXME.
    db_vm = task.vm
    dom = @qmfc.object(:class => 'domain', 'uuid' => db_vm.uuid)
    raise "Unable to locate VM to restore" unless dom

    filename = "/tmp/#{dom.uuid}.save"
    @logger.info "restoring vm #{dom.name} from #{filename}"
    result = dom.restore("/tmp/" + dom.uuid + ".save")
    raise "Error restoring VM: #{result.text}" unless result.status == 0

    set_vm_state(db_vm, Vm::STATE_RUNNING)
  end

  def migrate(db_vm, dest = nil)

    vm = @qmfc.object(:class => "domain", 'uuid' => db_vm.uuid)
    raise "Unable to find VM to migrate" unless vm
    src_node = @qmfc.object(:object_id => vm.node)
    raise "Unable to find node that VM is on??" unless src_node

    @logger.info "Migrating domain lookup complete, domain is #{vm}"

    vm_orig_state = db_vm.state
    set_vm_state(db_vm, Vm::STATE_MIGRATING)

    begin
      unless dest.nil? or dest.empty?
        if dest.to_i == db_vm.host_id
          raise "Cannot migrate from host " + src_node.hostname + " to itself!"
        end
        db_dst_host = find_host(dest.to_i)
      else
        db_dst_host = find_capable_host(db_vm)
      end

      dest_node = @qmfc.object(:class => 'node', 'hostname' => db_dst_host.hostname)
      raise "Unable to find host #{db_dst_host.hostname} to migrate to." unless dest_node

      volumes = []
      volumes += db_vm.storage_volumes
      @logger.debug("Connecting volumes: #{volumes}")
      connect_storage_pools(dest_node, volumes)

      # Sadly migrate with qpid is broken because it requires a connection between
      # both nodes and currently that can't happen securely.  For now we do it
      # the old fashioned way..
      src_uri = "qemu+tcp://" + src_node.hostname + "/system"
      dest_uri = "qemu+tcp://" + dest_node.hostname + "/system"
      @logger.debug("Migrating from #{src_uri} to #{dest_uri}")

      result = vm.migrate(dest_uri, Libvirt::Domain::MIGRATE_LIVE, '', '', 0, :timeout => 60 * 10)
      @logger.error "Error migrating VM: #{result.text}" unless result.status == 0

      # undefine can fail, for instance, if we live migrated from A -> B, and
      # then we are shutting down the VM on B (because it only has "transient"
      # XML).  Therefore, just ignore undefine errors so we do the rest
      # FIXME: we really should have a marker in the database somehow so that
      # we can tell if this domain was migrated; that way, we can tell the
      # difference between a real undefine failure and one because of migration
      result = vm.undefine

      @logger.info "Couldn't undefine old vm after migrate (probably fine): #{result.text}" unless result.status == 0

      # See if we can take down storage pools on the src host.
      teardown_storage_pools(src_node)
    rescue => ex
      @logger.error "Error: #{ex}"
      set_vm_state(db_vm, vm_orig_state)
      raise ex
    end

    db_vm.reload
    db_vm.state = Vm::STATE_RUNNING
    db_vm.host_id = db_dst_host.id
    db_vm.save!
  end

  def task_migrate_vm(task)
    @logger.info "starting task_migrate_vm"

    # here, we are given an id for a VM to migrate; we have to lookup which
    # physical host it is running on
    vm = find_vm(task)
    migrate(vm, task.args)
  end

  def storage_find_suitable_host(hardware_pool)
    # find all of the hosts in the same pool as the storage
    hardware_pool.hosts.each do |host|
      @logger.info "storage_find_suitable_host: host #{host.hostname} uuid #{host.uuid}"
      @logger.info "host.is_disabled is #{host.is_disabled}"
      if host.is_disabled.to_i != 0
        @logger.info "host #{host.hostname} is disabled"
        next
      end
      puts "searching for node with hostname #{host.hostname}"
      node = @qmfc.object(:class => 'node', 'hostname' => host.hostname)
      puts "node returned is #{node}"
      return node if node
    end

    raise "Could not find a host within this storage pool to scan the storage server."
  end

  def add_volume_to_db(db_pool, volume, owner = nil, group = nil, mode = nil)
    storage_volume = StorageVolume.factory(db_pool.get_type_label)
    storage_volume.path = volume.path
    storage_volume.size = volume.capacity / 1024
    storage_volume.storage_pool_id = db_pool.id
    storage_volume.write_attribute(storage_volume.volume_name, volume.name)
    storage_volume.key = volume.key
    storage_volume.lv_owner_perms = owner
    storage_volume.lv_group_perms = group
    storage_volume.lv_mode_perms = mode
    storage_volume.state = StorageVolume::STATE_AVAILABLE
    @logger.info "saving storage volume to db."
    storage_volume.save!
  end

  # The words "pool" and "volume" are ridiculously overloaded in our context.
  # Therefore, the refresh_pool method adopts this convention:
  # db_pool_phys: The underlying physical storage pool, as it is represented in
  #               the database
  # phys_libvirt_pool: The underlying physical storage, as it is represented in
  #                    libvirt
  # db_lvm_pool: The logical storage pool (if it exists), as it is represented
  #              in the database
  # lvm_libvirt_pool: The logical storage pool (if it exists), as it is
  #                   represented in the database

  def task_refresh_pool(task)
    @logger.info "starting task_refresh_pool"

    db_pool_phys = task.storage_pool
    raise "Could not find storage pool" unless db_pool_phys

    node = storage_find_suitable_host(db_pool_phys.hardware_pool)
    # FIXME: this is currently broken if you do something like:
    # 1.  Add an iscsi pool with 3 volumes (lun-1, lun-2, lun-3)
    # 2.  Scan it in
    # 3.  Remove lun-3 from the pool
    # 4.  Re-scan it
    # What will happen is that you will still have lun-3 available in the
    # database, even though it's not available in the pool anymore.  It's a
    # little tricky, though; we have to make sure that we don't pull the
    # database entry out from underneath a possibly running VM (or do we?)
    begin
      @logger.info("refresh being done on node #{node.hostname}")

      phys_libvirt_pool = LibvirtPool.factory(db_pool_phys, @logger)
      phys_libvirt_pool.connect(@qmfc, node)
      db_pool_phys.state = StoragePool::STATE_AVAILABLE
      db_pool_phys.save!

      begin
        # First we do the physical volumes.
        volumes = @qmfc.objects(:class => 'volume',
                                   'storagePool' => phys_libvirt_pool.remote_pool.object_id)
        volumes.each do |volume|
          storage_volume = StorageVolume.factory(db_pool_phys.get_type_label)

          existing_vol = StorageVolume.find(:first, :conditions =>
                            ["storage_pool_id = ? AND key = ?",
                            db_pool_phys.id, volume.key])

          puts "Existing volume is #{existing_vol}, searched for storage volume key and #{volume.key}"
          # Only add if it's not already there.
          if not existing_vol
            add_volume_to_db(db_pool_phys, volume);
          else
            @logger.debug "Scanned volume #{volume.key} already exists in db.."
          end

          # Now check for an LVM pool carving up this volume.
          lvm_name = volume.childLVMName
          next if lvm_name == ''

          @logger.debug "Child LVM exists for this volume - #{lvm_name}"
          lvm_db_pool = LvmStoragePool.find(:first, :conditions =>
                                          [ "vg_name = ?", lvm_name ])
          if lvm_db_pool == nil
            lvm_db_pool = LvmStoragePool.new
            lvm_db_pool[:type] = "LvmStoragePool"
            # set the LVM pool to the same hardware pool as the underlying storage
            lvm_db_pool.hardware_pool_id = db_pool_phys.hardware_pool_id
            lvm_db_pool.vg_name = lvm_name
            lvm_db_pool.state = StoragePool::STATE_AVAILABLE
            lvm_db_pool.save!
          end

          physical_vol = StorageVolume.find(:first, :conditions =>
                                            [ "path = ?",  volume.path])
          if physical_vol == nil
            # Hm. We didn't find the device in the storage volumes already.
            # something went wrong internally, and we have to bail
            raise "Storage internal physical volume error"
          end

          # OK, put the right lvm_pool_id in place
          physical_vol.lvm_pool_id = lvm_db_pool.id
          physical_vol.save!

          lvm_libvirt_pool = LibvirtPool.factory(lvm_db_pool, @logger)
          lvm_libvirt_pool.connect(@qmfc, node)

          lvm_volumes = @qmfc.objects(:class => 'volume',
                                   'storagePool' => lvm_libvirt_pool.remote_pool.object_id)
          lvm_volumes.each do |lvm_volume|

            lvm_storage_volume = StorageVolume.factory(lvm_db_pool.get_type_label)
            existing_vol = StorageVolume.find(:first, :conditions =>
                              ["storage_pool_id = ? AND key = ?",
                              lvm_db_pool.id, lvm_volume.key])
            if not existing_vol
              add_volume_to_db(lvm_db_pool, lvm_volume, "0744", "0744", "0744");
            else
              @logger.info "volume #{lvm_volume.key} already exists in db.."
            end
          end
        end
      end
    ensure
      phys_libvirt_pool.shutdown
    end
  end

  def task_create_volume(task)
    @logger.info "starting task_create_volume"

    db_volume = task.storage_volume
    raise "Could not find storage volume to create" unless db_volume

    db_pool = db_volume.storage_pool
    raise "Could not find storage pool" unless db_pool

    node = storage_find_suitable_host(db_pool.hardware_pool)

    begin
      if db_volume[:type] == "LvmStorageVolume"
        phys_libvirt_pool = get_libvirt_lvm_pool_from_volume(db_volume, @logger)
        phys_libvirt_pool.connect(@qmfc, node)
      end

      begin
        libvirt_pool = LibvirtPool.factory(db_pool, @logger)

        begin
          libvirt_pool.connect(@qmfc, node)
          volume_id = libvirt_pool.create_vol(*db_volume.volume_create_params)
          volume = @qmfc.object(:object_id => volume_id)
          raise "Unable to find newly created volume" unless volume

          @logger.debug "  volume:"
          for (key, val) in volume.properties
            @logger.debug "    property: #{key}, #{val}"
          end

          db_volume.reload
          db_volume.key = volume.key
          db_volume.path = volume.path
          db_volume.state = StorageVolume::STATE_AVAILABLE
          db_volume.save!

          db_pool.reload
          db_pool.state = StoragePool::STATE_AVAILABLE
          db_pool.save!
        rescue => ex
          @logger.error "Error saving new volume: #{ex.class}: #{ex.message}"
        ensure
          libvirt_pool.shutdown
        end
      ensure
        if db_volume[:type] == "LvmStorageVolume"
          phys_libvirt_pool.shutdown
        end
      end
    end

    # Now that we created a new volume, we need to refresh
    # the storage pools to ensure that they pick up the changes.
    # I currently refresh ALL storage pools at this time as it
    # shouldn't be a long operation and it doesn't hurt to refresh
    # them once in a while.
    pools = @qmfc.objects(:class => 'pool')
    pools.each do |pool|
      result = pool.refresh
      @logger.info "Problem refreshing pool (you can probably ignore this): #{result.text}" unless result.status == 0
    end

  end

  def task_delete_volume(task)
    @logger.info "starting task_delete_volume"

    db_volume = task.storage_volume
    raise "Could not find storage volume to create" unless db_volume

    db_pool = db_volume.storage_pool
    raise "Could not find storage pool" unless db_pool

    node = storage_find_suitable_host(db_pool.hardware_pool)

    begin
      if db_volume[:type] == "LvmStorageVolume"
        phys_libvirt_pool = get_libvirt_lvm_pool_from_volume(db_volume, @logger)
        phys_libvirt_pool.connect(@qmfc, node)
        @logger.info "connected to lvm pool.."
      end

      begin
        libvirt_pool = LibvirtPool.factory(db_pool, @logger)
        libvirt_pool.connect(@qmfc, node)

        begin
          volume = @qmfc.object(:class => 'volume',
                                   'storagePool' => libvirt_pool.remote_pool.object_id,
                                   'key' => db_volume.key)
          @logger.error "Unable to find volume to delete" unless volume

          # FIXME: we actually probably want to zero out the whole volume
          # here, so we aren't potentially leaking data from one user
          # to another.  There are two problems, though:
          # 1)  I'm not sure how I would go about zero'ing the data on a remote
          # machine, since there is no "libvirt_write_data" call
          # 2)  This could potentially take quite a while, so we want to spawn
          # off another thread to do it
          # result = volume.delete

          # If we don't find the volume we assume there was some error setting
          # it up, so just carry on here..
          volume.delete if volume

          @logger.info "Volume deleted successfully."

          # Note: we have to nil out the task_target because when we delete the
          # volume object, that also deletes all dependent tasks (including this
          # one), which leads to accessing stale tasks.  Orphan the task, then
          # delete the object; we can clean up orphans later (or not, depending
          # on the audit policy)
          task.reload
          task.task_target = nil
          task.save!

          db_volume.destroy
        ensure
          libvirt_pool.shutdown
        end
      ensure
        if db_volume[:type] == "LvmStorageVolume"
          phys_libvirt_pool.shutdown
        end
      end
    end
  end

  def task_clear_vms_host(task)
    @logger.info "starting task_clear_vms_host"
    src_host = task.host

    src_host.vms.each do |vm|
      migrate(vm)
    end
  end

  def mainloop()
    was_disconnected = false
    loop do

      if not @connection.connected?
        @logger.info("Cannot implement tasks, not connected to broker.  Sleeping.")
        sleep(@sleeptime * 3)
        was_disconnected = true
        next
      end

      @logger.info("Reconnected, resuming task checking..") if was_disconnected
      was_disconnected = false
      @qmfc.object(:class => 'agent')

      tasks = Array.new
      begin
        tasks = Task.find(:all, :conditions =>
                          [ "state = ?", Task::STATE_QUEUED ])
      rescue => ex
        @logger.error "1 #{ex.class}: #{ex.message}"
        if Task.connected?
          begin
            ActiveRecord::Base.connection.reconnect!
          rescue => norecon
            @logger.error "2 #{norecon.class}: #{norecon.message}"
          end
        else
          begin
            database_connect
          rescue => ex
            @logger.error "3 #{ex.class}: #{ex.message}"
          end
        end
      end

      tasks.each do |task|

        task.time_started = Time.now

        state = Task::STATE_FINISHED
        begin
          case task.action
            when VmTask::ACTION_CREATE_VM
              task_create_vm(task)
            when VmTask::ACTION_SHUTDOWN_VM
              task_shutdown_or_destroy_vm(task, :shutdown)
            when VmTask::ACTION_POWEROFF_VM
              task_shutdown_or_destroy_vm(task, :destroy)
            when VmTask::ACTION_START_VM
              task_start_vm(task)
            when VmTask::ACTION_SUSPEND_VM
              task_suspend_vm(task)
            when VmTask::ACTION_RESUME_VM
              task_resume_vm(task)
            when VmTask::ACTION_SAVE_VM
              task_save_vm(task)
            when VmTask::ACTION_RESTORE_VM
              task_restore_vm(task)
            when VmTask::ACTION_MIGRATE_VM
              task_migrate_vm(task)
            when StorageTask::ACTION_REFRESH_POOL
              task_refresh_pool(task)
            when StorageVolumeTask::ACTION_CREATE_VOLUME
              task_create_volume(task)
            when StorageVolumeTask::ACTION_DELETE_VOLUME
              task_delete_volume(task)
            when HostTask::ACTION_CLEAR_VMS: task_clear_vms_host(task)
          else
            @logger.error "unknown task " + task.action
            state = Task::STATE_FAILED
            task.message = "Unknown task type"
          end
        rescue Exception => ex
          @logger.error "Task action processing failed: #{ex.class}: #{ex.message}"
          @logger.error ex.backtrace
          state = Task::STATE_FAILED
          task.message = ex.message
        end

        task.state = state
        task.time_ended = Time.now
        begin
          task.save!
        rescue Exception => ex
          @logger.error "Error saving task state for task #{task.id}: #{ex.class}: #{ex.message}"
          @logger.error ex.backtrace
        end
        @logger.info "done"
      end
      # FIXME: here, we clean up "orphaned" tasks.  These are tasks
      # that we had to orphan (set task_target to nil) because we were
      # deleting the object they depended on.
      Task.find(:all, :conditions =>
                [ "task_target_id IS NULL and task_target_type IS NULL" ]).each do |task|
        task.destroy
      end
      sleep(@sleeptime)
    end
  end
end

taskomatic = TaskOmatic.new()
taskomatic.mainloop()

