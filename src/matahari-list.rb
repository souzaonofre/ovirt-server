#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "./dutils")

require 'rubygems'
require 'dutils'
require 'qmf'
require 'socket'

get_credentials('qpidd')

server, port = get_srv('qpidd', 'tcp')
raise "Unable to determine qpid server from DNS SRV record" if not server

puts "Connecting to #{server}, #{port}"

settings = Qmf::ConnectionSettings.new
settings.host = server
settings.port = port
# settings.mechanism = 'GSSAPI'
# settings.service = 'qpidd'

connection = Qmf::Connection.new(settings)
qmfc = Qmf::Console.new
broker = qmfc.add_connection(connection)
broker.wait_for_stable

hosts = qmfc.objects(Qmf::Query.new(:class => 'host'))
hosts.each do |host|
    puts "HOST: #{host.hostname}"
    for (key, val) in host.properties
        puts "  property: #{key}, #{val}"
    end

    # List cpus for current host
    cpus = qmfc.objects(Qmf::Query.new(:class => 'cpu', 'host' => host.object_id))
    cpus.each do |cpu|
        puts '  CPU:'
        for (key, val) in cpu.properties
            puts "    property: #{key}, #{val}"
        end
    end # cpus.each

    # List nics for current host
    nics = qmfc.objects(Qmf::Query.new(:class => 'nic', 'host' => host.object_id))
    nics.each do |nic|
        puts '  NIC: '
        for (key, val) in nic.properties
            puts "    property: #{key}, #{val}"
        end
    end

end
