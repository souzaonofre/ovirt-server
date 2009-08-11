#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "./dutils")

require "rubygems"
require "qpid"
require "dutils"

get_credentials('qpidd')

server, port = get_srv('qpidd', 'tcp')
raise "Unable to determine qpid server from DNS SRV record" if not server

srv = "amqp://#{server}:#{port}"
puts "Connecting to #{srv}.."
s = Qpid::Qmf::Session.new()
b = s.add_broker(srv, :mechanism => 'GSSAPI')

hosts = s.objects(:class => "host")
hosts.each do |host|
    puts "HOST: #{host.hostname}"
    for (key, val) in host.properties
        puts "  property: #{key}, #{val}"
    end

    # List cpus for current host
    cpus = s.objects(:class => "cpu", 'host' => host.object_id)
    cpus.each do |cpu|
        puts "  CPU:"
        for (key, val) in cpu.properties
            puts "    property: #{key}, #{val}"
        end
    end # cpus.each

    # List nics for current host
    nics = s.objects(:class => "nic", 'host' => host.object_id)
    nics.each do |nic|
        puts "  NIC: "
        for (key, val) in nic.properties
            puts "    property: #{key}, #{val}"
        end
    end

end
