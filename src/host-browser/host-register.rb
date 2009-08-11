#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "../dutils")
$: << File.join(File.dirname(__FILE__), ".")

require 'rubygems'
require 'qpid'
require 'monitor'
require 'dutils'
require 'daemons'
require 'optparse'
require 'logger'

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

$logfile = '/var/log/ovirt-server/host-register.log'

class HostRegister < Qpid::Qmf::Console

    # Use monitor mixin for mutual exclusion around checks to heartbeats
    # and updates to objects/heartbeats.

    include MonitorMixin

    def initialize()
        super()
        @cached_hosts = {}
        @heartbeats = {}
        @broker = nil
        @debug = false

        @do_daemon = true

        opts = OptionParser.new do |opts|
            opts.on('-h', '--help', 'Print help message') do
                puts opts
                exit
            end
            opts.on('-n', '--nodaemon', 'Run interactively (useful for debugging)') do |n|
                @do_daemon = false
            end
            opts.on('-d', '--debug', 'Print out debug messages') do
                @debug = true
            end
        end
        begin
            opts.parse!(ARGV)
        rescue OptionParser::InvalidOption
            puts opts
            exit
        end

        if @do_daemon
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
        @logger.info 'hostregister started.'

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
            @session = Qpid::Qmf::Session.new(:console => self, :manage_connections => true)
            @broker = @session.add_broker("amqp://#{server}:#{port}", :mechanism => 'GSSAPI')

         rescue Exception => ex
            @logger.error "Error in hostregister: #{ex}"
            @logger.error ex.backtrace
        end
    end

    def debugputs(msg)
        puts msg if @debug == true and @do_daemon == false
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

    def broker_connected(broker)
        @logger.info 'Connected to broker.'
    end

    def broker_disconnected(broker)
        @logger.error 'Broker disconnected.'
    end

    def agent_disconnected(agent)
        synchronize do
            debugputs "Marking objects for agent #{agent.broker.broker_bank}.#{agent.agent_bank} inactive"
            @cached_hosts.keys.each do |objkey|
                if @cached_hosts[objkey][:broker_bank] == agent.broker.broker_bank and
                   @cached_hosts[objkey][:agent_bank] == agent.agent_bank

                    cached_host = @cached_hosts[objkey]
                    cached_host[:active] = false
                    @logger.info "Host #{cached_host['hostname']} marked inactive"
                end
            end # @objects.keys.each
        end # synchronize do
    end

    def agent_connected(agent)
        synchronize do
            debugputs "Marking objects for agent #{agent.broker.broker_bank}.#{agent.agent_bank} active"
            @cached_hosts.keys.each do |objkey|
                if @cached_hosts[objkey][:broker_bank] == agent.broker.broker_bank and
                   @cached_hosts[objkey][:agent_bank] == agent.agent_bank

                    cached_host = @cached_hosts[objkey]
                    cached_host[:active] = true
                    @logger.info "Host #{cached_host['hostname']} marked active"
                end
            end # @objects.keys.each
        end # synchronize do
    end

    def update_cpus(host_qmf, host_db, cpu_info)

        @logger.info "Updating CPU info for host #{host_qmf.hostname}"
        debugputs "Broker reports #{cpu_info.length} cpus for host #{host_qmf.hostname}"

        # delete an existing CPUs and create new ones based on the data
        @logger.info "Deleting any existing CPUs for host #{host_qmf.hostname}"
        Cpu.delete_all(['host_id = ?', host_db.id])

        @logger.info "Saving new CPU records for host #{host_qmf.hostname}"
        cpu_info.each do |cpu|
            flags = (cpu.flags.length > 255) ? "#{cpu.flags[0..251]}..." : cpu.flags
            detail = Cpu.new(
                         'cpu_number'      => cpu.cpunum,
                         'core_number'     => cpu.corenum,
                         'number_of_cores' => cpu.numcores,
                         'vendor'          => cpu.vendor,
                         'model'           => cpu.model.to_s,
                         'family'          => cpu.family.to_s,
                         'cpuid_level'     => cpu.cpuid_lvl,
                         'speed'           => cpu.speed.to_s,
                         'cache'           => cpu.cache.to_s,
                         'flags'           => flags)

            host_db.cpus << detail

            debugputs "Added new CPU for #{host_qmf.hostname}: "
            debugputs "CPU #       : #{cpu.cpunum}"
            debugputs "Core #      : #{cpu.corenum}"
            debugputs "Total Cores : #{cpu.numcores}"
            debugputs "Vendor      : #{cpu.vendor}"
            debugputs "Model       : #{cpu.model}"
            debugputs "Family      : #{cpu.family}"
            debugputs "Cpuid_lvl   : #{cpu.cpuid_lvl}"
            debugputs "Speed       : #{cpu.speed}"
            debugputs "Cache       : #{cpu.cache}"
            debugputs "Flags       : #{flags}"
        end

        @logger.info "Saved #{cpu_info.length} cpus for #{host_qmf.hostname}"
    end

    def update_nics(host_qmf, host_db, nic_info)

        # Update the NIC details for this host:
        # -if the NIC exists, then update the IP address
        # -if the NIC does not exist, create it
        # -any nic not in this list is deleted

        @logger.info "Updating NIC records for host #{host_qmf.hostname}"
        debugputs "Broker reports #{nic_info.length} NICs for host"

        nics = Array.new
        nics_to_delete = Array.new

        host_db.nics.each do |nic|
            found = false

            nic_info.each do |detail|
                # if we have a match, then update the database and remove
                # the received data to avoid creating a dupe later
                @logger.info "Searching for existing record for: #{detail.macaddr.upcase} in host #{host_qmf.hostname}"
                if detail.macaddr.upcase == nic.mac
                    @logger.info "Updating details for: #{detail.interface} [#{nic.mac}]}"
                    nic.bandwidth = detail.bandwidth
                    nic.interface_name = detail.interface
                    nic.save!
                    found = true
                    nic_info.delete(detail)
                end
            end

            # if the record wasn't found, then remove it from the database
            unless found
                @logger.info "Marking NIC for removal: #{nic.interface_name} [#{nic.mac}]"
                nics_to_delete << nic
            end
        end

        debugputs "Deleting #{nics_to_delete.length} NICs that are no longer part of host #{host_qmf.hostname}"
        nics_to_delete.each do |nic|
            @logger.info "Removing NIC: #{nic.interface_name} [#{nic.mac}]"
            host_db.nics.delete(nic)
        end

        # iterate over any nics left and create new records for them.
        debugputs "Adding new records for #{nic_info.length} NICs to host #{host_qmf.hostname}"
        nic_info.each do |nic|
            detail = Nic.new(
            'mac'            => nic.macaddr.upcase,
            'bandwidth'      => nic.bandwidth,
            'interface_name' => nic.interface,
            'usage_type'     => 1)

            host_db.nics << detail

            @logger.info "Added NIC #{nic.interface} with MAC #{nic.macaddr} to host #{host_qmf.hostname}"
        end
    end

    def object_props(broker, obj)
        target = obj.schema.klass_key.package
        type = obj.schema.klass_key.klass_name
        return if target != 'com.redhat.matahari' or type != 'host'

        # Fix a race where the properties of an object are published by a reconnecting
        # host (thus marking it active) right before the heartbeat timer considers it dead
        # (and marks it inactive)
        @heartbeats.delete("#{obj.object_id.agent_bank}.#{obj.object_id.broker_bank}")

        already_cache = false
        already_in_db = false

	# Grab the cpus and nics associated before we take any locks
	cpu_info = @session.objects(:class => 'cpu', 'host' => obj.object_id)
	nic_info = @session.objects(:class => 'nic', 'host' => obj.object_id)

        synchronize do
            cached_host = @cached_hosts[obj.object_id.to_s]
            host = Host.find(:first, :conditions => ['hostname = ?', obj.hostname])

            already_cache = true if cached_host != nil
            already_in_db = true if host != nil

            @logger.info "Node #{obj.hostname} with UUID #{obj.uuid} detected, already exists in db? is #{already_in_db}"

            # Four cases apply here:
            # 1. Not in db, but is cached:
            #    Impossible, since we don't cache unless we could add to db.
            #    Throw an exception here.
            #
            # 2. Not in db or cache:
            #    Seeing host for the first time. Put in db and cache.
            #
            # 3. In db, not in cache:
            #    Have not seen host since last invocation of daemon. Update
            #    db entry, and add to cache.
            #
            # 4. In db, in cache:
            #    Property updated; update in db and cache.

            # Case 1:
            if already_cache and not already_in_db
                error = "Error: Found host in cache that is not present in db!"
                @logger.error error
                throw error
            end

            # All other cases collapse to add-or-update db and cache

            # Add to db if necessary
            if not already_in_db
                debugputs "Didn't find host #{obj.hostname} in db!"
                begin
                    @logger.info "Creating a new record for #{obj.hostname}..."

                    host = Host.create(
                               'uuid'            => obj.uuid,
                               'hostname'        => obj.hostname,
                               'hypervisor_type' => obj.hypervisor,
                               'arch'            => obj.arch,
                               'memory'          => obj.memory,
                               'is_disabled'     => 0,
                               'hardware_pool'   => HardwarePool.get_default_pool,
                              # Let host-status mark it available when it
                              # successfully connects to it via libvirt.
                               'state'           => Host::STATE_UNAVAILABLE)

                    debugputs 'Added new host:'
                    debugputs "uuid: #{obj.uuid}"
                    debugputs "hostname: #{obj.hostname}"
                    debugputs "hypervisor: #{obj.hypervisor}"
                    debugputs "arch: #{obj.arch}"
                    debugputs "memory: #{obj.memory}"

                rescue Exception => error
                    @logger.error "Error while creating record: #{error.message}"
                   # We haven't added the host to the db, and it isn't cached, so we just
                   # return without having done anything. To retry, the host will have to
                   # restart its agent.
                    return
                end
            else
                @logger.info "Updating record for #{obj.hostname}..."
                host.uuid            = obj.uuid
                host.hostname        = obj.hostname
                host.hypervisor_type = obj.hypervisor
                host.arch            = obj.arch
                host.memory          = obj.memory

                debugputs 'Updated host #{obj.hostname} with new details:'
                debugputs "uuid: #{obj.uuid}"
                debugputs "hypervisor: #{obj.hypervisor}"
                debugputs "arch: #{obj.arch}"
                debugputs "memory: #{obj.memory}"
            end # not already_in_db

            update_cpus(obj, host, cpu_info)
            update_nics(obj, host, nic_info)

            host.save!
            debugputs "Finished flushing host #{obj.hostname} to db"

            # Add to cache if necessary
            if not already_cache
                debugputs "Did not find host #{obj.hostname} in cache!"
                # Check if there is a stale entry for host that we can refresh.
                # We iterate over each host in the cache. If we find an entry
                # that matches hostname, we rekey it in hash.
                @cached_hosts.each do |objkey, h|
                    if h['hostname'] == obj.hostname
                        debugputs "Found stale entry for #{obj.hostname} with key #{objkey}"
                        debugputs "Refreshing with key #{obj.object_id.to_s}"
                        @cached_hosts.delete(objkey)
                        @cached_hosts[obj.object_id.to_s] = h
                        cached_host = h
                        break
                    end
                end # @cached_hosts.each

                if cached_host == nil
                    debugputs "Creating new entry for #{obj.hostname} with key #{obj.object_id.to_s}"
                    cached_host = {}
                    @cached_hosts[obj.object_id.to_s] = cached_host
                end

                # By now, we either rekeyed a stale entry or started a new one.
                # Update the bookkeeping parts of the data.
                cached_host[:obj_key] = obj.object_id.to_s
                cached_host[:broker_bank] = obj.object_id.broker_bank
                cached_host[:agent_bank] = obj.object_id.agent_bank
            end # not already_cache

            # For now, only cache identity information (leave CPU/NIC/etc. to db only)
            cached_host[:active] = true
            cached_host['hostname'] = obj.hostname
            cached_host['uuid'] = obj.uuid
            cached_host['hypervisor'] = obj.hypervisor
            cached_host['arch'] = obj.arch
        end # synchronize do
    end # def object_props

    def heartbeat(agent, timestamp)
        return if agent == nil
        synchronize do
            bank_key = "#{agent.agent_bank}.#{agent.broker.broker_bank}"
            @heartbeats[bank_key] = [agent, timestamp]
        end
    end

    def new_agent(agent)
        key = "#{agent.agent_bank}.#{agent.broker.broker_bank}"
        debugputs "Agent #{key} connected!"
        agent_connected(agent)
    end

    def del_agent(agent)
        key = "#{agent.agent_bank}.#{agent.broker.broker_bank}"
        debugputs "Agent #{key} disconnected!"
        @heartbeats.delete(key)
        agent_disconnected(agent)
    end

    def check_heartbeats()
        begin
            while true
                sleep(5)
                synchronize do
                    # Get seconds from the epoch
                    t = Time.new.to_i

                    @heartbeats.keys.each do | key |
                        agent, timestamp = @heartbeats[key]

                        # Heartbeats from qpid are in microseconds, we just need seconds..
                        s = timestamp / 1000000000
                        delta = t - s

                        if delta > 30
                            # No heartbeat for 30 seconds.. deal with dead/disconnected agent.
                            debugputs "Agent #{key} timed out!"
                            @heartbeats.delete(key)
                            agent_disconnected(agent)
                        end
                    end

                    # Print out current objects
                    debugputs '===== Current Objects ====='
                    @cached_hosts.keys.each do |objkey|
                        cached_host = @cached_hosts[objkey]
                        cached_host.each do |key, val|
                            debugputs "\t#{key} : #{val}\n"
                        end
                    end
                    debugputs '=====       Done      ====='

                end # synchronize do
            end # while true
        rescue Exception => ex
            @logger.error "Error in hostregister: #{ex}"
            @logger.error ex.backtrace
        end # end begin-rescue
    end # def check_heartbeats

end # Class HostRegister

def main()
    hostreg = HostRegister.new()
    hostreg.check_heartbeats()
end

main()
