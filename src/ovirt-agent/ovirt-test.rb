#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "./dutils")

require "rubygems"
require "qpid"

srv = "amqp://mc.mains.net"

puts "Connecting to #{srv}.."
s = Qpid::Qmf::Session.new()
b = s.add_broker(srv)

while true:
    ovirt = s.object(:class => "Ovirt")
    puts "id is #{ovirt.object_id}"
    raise "ACK! NO ovirt class!" unless ovirt
    puts "ovirt.version is #{ovirt.version}"
    ovirt_by_id = s.object(:object_id => ovirt.object_id)
    puts "ovirt_by_id.version is #{ovirt_by_id.version}"

    vms = s.objects(:class => "VmDef")
    vms.each do |vm|
      puts "VmDef: #{vm.description}"
      for (key, val) in vm.properties
        puts "  property: #{key}, #{val}"
      end
      vm2 = s.object(:object_id => vm.object_id)
      puts "vm2 is #{vm2}"
    end

    result = ovirt.create_vm_def('new_vm', 1, 512 * 1024, '', '')
    puts "result.status is #{result.status}"
    puts "result.text is #{result.text}"
    puts "result.vm is #{result.vm}" if result.status == 0
    puts '----------------------------'
    sleep(5)
end


