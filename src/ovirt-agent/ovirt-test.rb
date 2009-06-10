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
end

puts "VM Pools:"
vmps = s.objects(:class => "VmPool")
vmps.each do |vmp|
  puts "VM pool: #{vmp.name}"
  for (key, val) in vmp.properties
    puts "  property: #{key}, #{val}"
  end
end

#result = ovirt.create_vm_def('new_vm', 1, 512 * 1024, '', '')
#puts "result.status is #{result.status}"
#puts "result.text is #{result.text}"
#puts "result.vm is #{result.vm}" if result.status == 0
#puts '----------------------------'
