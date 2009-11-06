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

nodes = qmfc.objects(Qmf::Query.new(:class => "node"))
nodes.each do |node|
    puts "node: #{node.hostname}"
    for (key, val) in node.properties
        puts "  property: #{key}, #{val}"
    end

    # Find any domains that on the current node.
    domains = qmfc.objects(Qmf::Query.new(:class => "domain", 'node' => node.object_id))
    domains.each do |domain|
        r = domain.getXMLDesc()
        puts "getXMLDesc() status: #{r.status}"
        puts "getXMLDesc() status: #{r.text}"
        if r.status == 0
            puts "xml length: #{r.description.length}"
        end

        puts "  domain: #{domain.name}, state: #{domain.state}, id: #{domain.id}"
        for (key, val) in domain.properties
            puts "    property: #{key}, #{val}"
        end
    end

    pools = qmfc.objects(Qmf::Query.new(:class => "pool", 'node' => node.object_id))
    pools.each do |pool|
        puts "  pool: #{pool.name}"
        for (key, val) in pool.properties
            puts "    property: #{key}, #{val}"
        end

        r = pool.getXMLDesc()
        puts "getXMLDesc() status: #{r.status}"
        puts "getXMLDesc() text: #{r.text}"
        if r.status == 0
            puts "xml length: #{r.description.length}"
        end

        # Find volumes that are part of the pool.
        volumes = qmfc.objects(Qmf::Query.new(:class => "volume", 'pool' => pool.object_id))
        volumes.each do |volume|
            puts "    volume: #{volume.name}"
            for (key, val) in volume.properties
                puts "      property: #{key}, #{val}"
            end
        end
    end
end
