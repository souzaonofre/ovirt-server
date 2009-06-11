#!/usr/bin/ruby

$: << File.join(File.dirname(__FILE__), "./dutils")

require "rubygems"
require "qpid"

if ARGV.size == 1
  srv = ARGV[0]
else
  srv = "amqp://localhost"
end

puts "Connecting to #{srv}.."
s = Qpid::Qmf::Session.new()
b = s.add_broker(srv)

# This segfaults in F10 (ruby-1.8.6.287-2.fc10.x86_64)
# p s.objects(:class => "Ovirt")

ovirt = s.object(:class => "Ovirt")
puts "id is #{ovirt.object_id}"
raise "ACK! NO ovirt class!" unless ovirt
puts "ovirt.version is #{ovirt.version}"
ovirt_by_id = s.object(:object_id => ovirt.object_id)
puts "ovirt_by_id.version is #{ovirt_by_id.version}"

puts "Hardware Pools:"
hwps = s.objects(:class => "HardwarePool")
hwps.each do |hwp|
  puts "Hardware pool: #{hwp.name}"
  puts "VM pools in hardware pool:"
  vmps = s.objects(:class => "VmPool", 'hardware_pool' => hwp.object_id)
  vmps.each do |vmp|
    puts "VM pool: #{vmp.name}"
    for (key, val) in vmp.properties
      puts "  property: #{key}, #{val}"
    end
  end
end

hwp = s.object(:class => "HardwarePool", 'name' => 'default')

vmp = s.object(:class => "VmPool", 'hardware_pool' => hwp.object_id, 'name' => 'new_vm_pool')

if !vmp
  result = hwp.create_vm_pool('new_vm_pool')
  puts "result is #{result.status}"
  puts "Error: #{result.text}" if result.status != 0
  puts "New vm pool #{result.vm_pool}" if result.status == 0
else
  puts "Pool new_vm_pool already exists."
end



#result = ovirt.create_vm_def('new_vm', 1, 512 * 1024, '', '')
#puts "result.status is #{result.status}"
#puts "result.text is #{result.text}"
#puts "result.vm is #{result.vm}" if result.status == 0
#puts '----------------------------'
