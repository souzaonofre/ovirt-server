#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "../dutils")
$: << File.join(File.dirname(__FILE__), ".")

require 'rubygems'
require 'monitor'
require 'dutils'
require 'daemons'
require 'optparse'
require 'logger'
require 'vnc'
require 'qmf'
require 'socket'

include Daemonize

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

$logfile = '/var/log/ovirt-server/db-omatic.log'

class DbOmatic < Qmf::ConsoleHandler
    # Use monitor mixin for mutual exclusion around checks to heartbeats
    # and updates to objects/heartbeats.
    include MonitorMixin

    def initialize()
        super()
        @cached_objects = {}
        @heartbeats = {}
        @broker = nil

        do_daemon = true

        opts = OptionParser.new do |opts|
            opts.on("-h", "--help", "Print help message") do
                puts opts
                exit
            end
            opts.on("-n", "--nodaemon", "Run interactively (useful for debugging)") do |n|
                do_daemon = false
            end
        end
        begin
            opts.parse!(ARGV)
        rescue OptionParser::InvalidOption
            puts opts
            exit
        end

        if do_daemon
            # XXX: This gets around a problem with paths for the database stuff.
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
        @logger.info "dbomatic started."

        begin
            ensure_credentials
            database_connect

            server, port = nil
            sleepy = 5
            while true do
                server, port = get_srv('qpidd', 'tcp')
                break if server
                @logger.error "Unable to determine qpid server from DNS SRV record, retrying.." if not server
                sleep(sleepy)
                sleepy *= 2 if sleepy < 120
            end

            @logger.info "Connecting to amqp://#{server}:#{port}"
            @settings = Qmf::ConnectionSettings.new
            @settings.host = server
            @settings.port = port
#            @settings.mechanism = 'GSSAPI'
#            @settings.service = 'qpidd'
            @settings.sendUserId = false

            @connection = Qmf::Connection.new(@settings)
            @qmfc = Qmf::Console.new(self)
            @broker = @qmfc.add_connection(@connection)
            @broker.wait_for_stable

            db_init_cleanup
        rescue Exception => ex
            @logger.error "Error in db-omatic: #{ex}"
            @logger.error ex.backtrace
        end
    end

    def ensure_credentials()
        get_credentials('qpidd')
        Thread.new do
            while true do
                sleep(3600)
                get_credentials('qpidd')
            end
        end
    end

    def set_vm_stopped(db_vm)
        db_vm.host_id = nil
        db_vm.memory_used = nil
        db_vm.num_vcpus_used = nil
        db_vm.needs_restart = nil
        db_vm.vnc_port = nil
        db_vm.state = Vm::STATE_STOPPED
    end

    def update_domain_state(domain, state_override = nil)
        vm = Vm.find(:first, :conditions => [ "uuid = ?", domain['uuid'] ])
        if vm == nil
            @logger.info "VM Not found in database, must be created by user; ignoring."

            #XXX: I mark this one as 'synced' here even though we couldn't sync
            #it because there really should be a db entry for every vm unless it
            #was created outside of ovirt.
            domain[:synced] = true
            return
        end

        if state_override != nil
            state = state_override
        else
            # FIXME: Some of these translations don't seem right.  Shouldn't we be using
            # the libvirt states throughout ovirt?
            case domain['state']
                when "nostate"
                    state = Vm::STATE_PENDING
                when "running"
                    state = Vm::STATE_RUNNING
                when "blocked"
                    state = Vm::STATE_SUSPENDED #?
                when "paused"
                    state = Vm::STATE_SUSPENDED
                when "shutdown"
                    state = Vm::STATE_STOPPED
                when "shutoff"
                    state = Vm::STATE_STOPPED
                when "crashed"
                    state = Vm::STATE_STOPPED
                else
                    state = Vm::STATE_PENDING
            end
        end

        begin
          # find open vm host history for this vm
          # NOTE: db-omatic is currently the only user for VmHostHistory, so
          # using optimistic locking is fine. Someday this might need changing.
          history = VmHostHistory.find(:first, :conditions => ["vm_id = ? AND time_ended is NULL", vm.id])

          if state == Vm::STATE_RUNNING
             if history.nil?
               history = VmHostHistory.new
               history.vm = vm
               history.host = vm.host
               history.vnc_port = vm.vnc_port
               history.state = state
               history.time_started = Time.now
               history.save!
             end

             VmVnc.forward(vm)
          elsif state != Vm::STATE_PENDING
             VmVnc.close(vm, history)

             unless history.nil? # throw an exception if this fails?
               history.time_ended = Time.now
               history.state = state
               history.save!
             end
          end

        rescue Exception => e # just log any errors here
            @logger.error "Error with VM #{domain['name']} operation: " + e
        end

        @logger.info "Updating VM #{domain['name']} to state #{state}"

        if state == Vm::STATE_STOPPED
            @logger.info "VM has moved to stopped, clearing VM attributes."
            qmf_vm = @qmfc.object(Qmf::Query.new(:class => "domain"), 'uuid' => vm.uuid)
            if qmf_vm
                @logger.info "Deleting VM #{vm.description}."
                result = qmf_vm.undefine
                if result.status == 0
                    @logger.info "Delete of VM #{vm.description} successful, syncing DB."
                    set_vm_stopped(vm)
                end
            end
        # If we are running, update the node that the domain is running on
        elsif state == Vm::STATE_RUNNING
            @logger.info "VM is running, determine the node it is running on"
            qmf_vm = @qmfc.object(Qmf::Query.new(:class => "domain"), 'uuid' => vm.uuid)
            if qmf_vm
                qmf_host = @qmfc.object(Qmf::Query.new(:class => "node", :object_id => qmf_vm.node))
                db_host = Host.find(:first, :conditions => ['hostname = ?', qmf_host.hostname])
                @logger.info "VM #{vm.description} is running on node #{db_host.hostname}"
                vm.host_id = db_host.id
            elsif
              @logger.info "Cannot find in QMF the node corresponding to #{domain['name']} "
            end
        end

        vm.state = state

        begin
            vm.save!
        rescue ActiveRecord::StaleObjectError => e
            @logger.error "Optimistic locking failed for VM #{vm.description}, retrying."
            @logger.error e.backtrace
            # don't retry now until it's been tested.
            # return update_domain_state(domain, state_override)
            return
        end

        domain[:synced] = true
    end

    def update_host_state(host_info, state)
        db_host = Host.find(:first, :conditions => [ "hostname = ?", host_info['hostname'] ])
        if db_host
            @logger.info "Marking host #{host_info['hostname']} as state #{state}."
            db_host.state = state
            db_host.hypervisor_type = host_info['hypervisorType']
            db_host.arch = host_info['model']
            db_host.memory = host_info['memory']
            # XXX: Could be added..
            #db_host.mhz = host_info['mhz']
            # XXX: Not even sure what this is.. :)
            #db_host.lock_version = 2
            # XXX: This would just be for init..
            #db_host.is_disabled = 0

            begin
                db_host.save!
            rescue ActiveRecord::StaleObjectError => e
                @logger.error "Optimistic locking failure on host #{host_info['hostname']}, retrying."
                @logger.error e.backtrace
                # don't retry now until it's been tested.
                #return update_host_state(host_info, state)
                return
            end
            host_info[:synced] = true

            if state == Host::STATE_AVAILABLE
                Thread.new do
                    @logger.info "#{host_info['hostname']} has moved to available, sleeping for updates to vms."
                    sleep(20)

                    # At this point we want to set all domains that are
                    # unreachable to stopped.  We're using a thread here to
                    # sleep for 10 seconds outside of the main dbomatic loop.
                    # If after 10 seconds with this host up there are still
                    # domains set to 'unreachable', then we're going to guess
                    # the node rebooted and so the domains should be set to
                    # stopped.
                    @logger.info "Checking for dead VMs on newly available host #{host_info['hostname']}."

                    # Double check to make sure this host is still up.
                    begin
                        qmf_host = @qmfc.objects(Qmf::Query.new(:class => "node"), 'hostname' => host_info['hostname'])
                        if !qmf_host
                            @logger.info "Host #{host_info['hostname']} is not up after waiting 20 seconds, skipping dead VM check."
                        else
                            db_vm = Vm.find(:all, :conditions => ["host_id = ? AND state = ?", db_host.id, Vm::STATE_UNREACHABLE])
                            db_vm.each do |vm|
                                @logger.info "Moving vm #{vm.description} in state #{vm.state} to state stopped."
                                set_vm_stopped(vm)
                                vm.save!
                            end
                        end
                    rescue Exception => e # just log any errors here
                        @logger.info "Exception checking for dead VMs (could be normal): #{e.message}"
                        @logger.info e.backtrace
                    end
                end
            end
        else
            # FIXME: This would be a newly registered host.  We could put it in the database.
            @logger.info "Unknown host #{host_info['hostname']}, probably not registered yet??"
            # XXX: So it turns out this can happen as there is a race condition on bootup
            # where the registration takes longer than libvirt-qpid does to relay information.
            # So in this case, we mark this object as not synced so it will get resynced
            # again in the heartbeat.
            host_info[:synced] = false
        end
    end

    def object_update(obj, hasProps, hasStats)
        target = obj.object_class.package_name
        type = obj.object_class.class_name
        return if target != "com.redhat.libvirt"

        if hasProps
            update_props(obj, type)
        end
        if hasStats
            update_stats(obj, type)
	end
    end

    def update_props(obj, type)
        # I just sync this whole thing because there shouldn't be a lot of contention here..
        synchronize do
            values = @cached_objects[obj.object_id.to_s]
            new_object = false

            if values == nil
                values = {}

                # Save the agent and broker bank so that we can tell what objects
                # are expired when the heartbeat for them stops.
                values[:agent_key] = obj.object_id.agent_key
                values[:obj_key] = obj.object_id.to_s
                values[:class_type] = type
                values[:timed_out] = false
                values[:synced] = false
                @logger.info "New object type #{type}"

                new_object = true

                if type == "node"
                    # It's a new node object..
                    # We want to make sure there are no old objects for this same host name
                    # that can mess up our timeouts etc.  It's also good bookkeeping.
                    @cached_objects.each do |objkey, o|
                        if o[:class_type] == 'node' and o['hostname'] == obj.hostname
                            @logger.info "Old object for host #{o['hostname']} exists, removing it from cache"
                            @cached_objects.delete(objkey)
                        end
                    end
                end

                # Same thing for domains..
                if type == "domain"
                    @cached_objects.each do |objkey, o|
                        if o[:class_type] == 'domain' and o['uuid'] == obj.uuid and o['name'] == obj.name
                            @logger.info "Old object for domain #{o['name']} exists, removing it from cache"
                            @cached_objects.delete(objkey)
                        end
                    end
                end

                @cached_objects[obj.object_id.to_s] = values
            end

            update_domain = false

            obj.properties.each do |key, newval|
                if values[key.to_s] != newval
                    values[key.to_s] = newval
                    #puts "new value for property #{key} : #{newval}"
                    if type == "domain" and key.to_s == "state"
                        update_domain = true
                    end
                end
            end

            update_host_state(values, Host::STATE_AVAILABLE) if new_object and type == 'node'
            update_domain_state(values) if update_domain
        end
    end

   def update_stats(obj, type)
        synchronize do
            values = @cached_objects[obj.object_id.to_s]
            if values == nil
                values = {}
                @cached_objects[obj.object_id.to_s] = values
                values[:agent_key] = obj.object_id.agent_key
                values[:class_type] = type
                values[:timed_out] = false
                values[:synced] = false
            end

            obj.statistics.each do |key, newval|
                if values[key.to_s] != newval
                    values[key.to_s] = newval
                end
            end
        end
    end

    def agent_heartbeat(agent, timestamp)
        puts "heartbeat from agent #{agent.key}"
        return if agent == nil
        synchronize do
            @heartbeats[agent.key] = [agent, timestamp]
        end
    end

    def agent_added(agent)
        @logger.info("Agent connected: #{agent.key}")
    end

    def agent_deleted(agent)
        agent_disconnected(agent)
    end

    # This method marks objects associated with the given agent as timed out/invalid.  Called either
    # when the agent heartbeats out, or we get a del_agent callback.
    def agent_disconnected(agent)
	puts "agent_disconnected: #{agent.key}"
        @cached_objects.keys.each do |objkey|
            if @cached_objects[objkey][:agent_key] == agent.key
                values = @cached_objects[objkey]
                if values[:timed_out] == false
                    @logger.info "Marking object of type #{values[:class_type]} with key #{objkey} as timed out."

                    if values[:class_type] == 'node'
                        update_host_state(values, Host::STATE_UNAVAILABLE)
                    elsif values[:class_type] == 'domain'
                        update_domain_state(values, Vm::STATE_UNREACHABLE)
                    end
                end
            values[:timed_out] = true
            end
        end
        @heartbeats.delete(agent.key)
    end

    # The opposite of above, this is called when an agent is alive and well and makes sure
    # all of the objects associated with it are marked as valid.
    def agent_connected(agent)

        @cached_objects.keys.each do |objkey|
            if @cached_objects[objkey][:agent_key] == agent.key
                values = @cached_objects[objkey]
                if values[:timed_out] == true or values[:synced] == false
                    if values[:class_type] == 'node'
                        update_host_state(values, Host::STATE_AVAILABLE)
                    elsif values[:class_type] == 'domain'
                        update_domain_state(values)
                    end
                    values[:timed_out] = false
                end
            end
        end
    end

    # This cleans up the database on startup so that everything is marked unavailable etc.
    # Once everything comes online it will all be marked as available/up again.
    def db_init_cleanup()
        db_host = Host.find(:all)
        db_host.each do |host|
            @logger.info "Marking host #{host.hostname} unavailable"
            host.state = Host::STATE_UNAVAILABLE
            host.save!
        end

        begin
           VmVnc.deallocate_all
         rescue Exception => e # just log any errors here
            @logger.error "Error with closing all VM VNCs operation: #{e.message}"
         end

        # On startup, since we don't know the previous states of anything, we basically
        # do a big sync up with teh states of all VMs.  We don't worry about hosts since
        # they are very simple and are either up or down, but it's possible we left
        # VMs in various states that are no longer applicable to this moment.
        db_vm = Vm.find(:all)
        db_vm.each do |vm|
            set_stopped = false
            # Basically here we are looking for VMs which are not up in some form or another and setting
            # them to stopped.  VMs that exist as QMF objects will get set appropriately when the objects
            # appear on the bus.
            begin
                qmf_vm = @qmfc.object(Qmf::Query.new(:class => "domain"), 'uuid' => db_vm.uuid)
                if qmf_vm == nil
                    set_stopped = true
                end
            rescue Exception => ex
                set_stopped = true
            end

            if set_stopped
                @logger.info "On startup, VM #{vm.description} is not found, setting to stopped."
                set_vm_stopped(vm)
                vm.save!
            end
        end
    end

    # This is the mainloop that is called into as a separate thread.  This just loops through
    # and makes sure all the agents are still reporting.  If they aren't they get marked as
    # down.
    def check_heartbeats()
        begin
            while true
                sleep(5)

                synchronize do
                    # Get seconds from the epoch
                    t = Time.new.to_i

                    puts "going through heartbeats.."
                    @heartbeats.keys.each do | key |
                        agent, timestamp = @heartbeats[key]

                        # Heartbeats from qpid are in microseconds, we just need seconds..
                        s = timestamp / 1000000000
                        delta = t - s

                        puts "Checking time delta for agent #{agent.key} - #{delta}"

                        if delta > 30
                            # No heartbeat for 30 seconds.. deal with dead/disconnected agent.
                            agent_disconnected(agent)
                        else
                            agent_connected(agent)
                        end
                    end
                end
            end
        rescue Exception => ex
            @logger.error "Error in db-omatic: #{ex}"
            @logger.error ex.backtrace
        end
    end
end

def main()
    Thread.abort_on_exception = true
    dbsync = DbOmatic.new()
    dbsync.check_heartbeats()
end

main()
