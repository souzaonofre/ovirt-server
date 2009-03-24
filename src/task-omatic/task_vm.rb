# Copyright (C) 2008 Red Hat, Inc.
# Written by Chris Lalancette <clalance@redhat.com>
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

require 'rexml/document'
include REXML

gem 'cobbler'
require 'cobbler'

def find_host(host_id)
  host = Host.find(:first, :conditions => [ "id = ?", host_id])

  if host == nil
    # Hm, we didn't find the host_id.  Seems odd.  Return a failure
    raise "Could not find host_id " + host_id.to_s
  end

  return host
end


def create_vm_xml(name, uuid, memAllocated, memUsed, vcpus, bootDevice,
                  macAddr, bridge, diskDevices)
  doc = Document.new

  doc.add_element("domain", {"type" => "kvm"})

  doc.root.add_element("name").add_text(name)

  doc.root.add_element("uuid").add_text(uuid)

  doc.root.add_element("memory").add_text(memAllocated.to_s)

  doc.root.add_element("currentMemory").add_text(memUsed.to_s)

  doc.root.add_element("vcpu").add_text(vcpus.to_s)

  doc.root.add_element("os")
  doc.root.elements["os"].add_element("type").add_text("hvm")
  doc.root.elements["os"].add_element("boot", {"dev" => bootDevice})

  doc.root.add_element("clock", {"offset" => "utc"})

  doc.root.add_element("on_poweroff").add_text("destroy")

  doc.root.add_element("on_reboot").add_text("restart")

  doc.root.add_element("on_crash").add_text("destroy")

  doc.root.add_element("devices")
  doc.root.elements["devices"].add_element("emulator").add_text("/usr/bin/qemu-kvm")

  devs = ['hda', 'hdb', 'hdc', 'hdd']
  which_device = 0
  diskDevices.each do |disk|
    is_cdrom = (disk =~ /\.iso/) ? true : false

    diskdev = Element.new("disk")
    diskdev.add_attribute("type", is_cdrom ? "file" : "block")
    diskdev.add_attribute("device", is_cdrom ? "cdrom" : "disk")

    if is_cdrom
      diskdev.add_element("readonly")
      diskdev.add_element("source", {"file" => disk})
      diskdev.add_element("target", {"dev" => devs[which_device], "bus" => "ide"})
    else
      diskdev.add_element("source", {"dev" => disk})
      diskdev.add_element("target", {"dev" => devs[which_device]})
    end

    doc.root.elements["devices"] << diskdev
    which_device += 1
  end

  unless macAddr.nil? || bridge.nil? || macAddr == "" || bridge == ""
    doc.root.elements["devices"].add_element("interface", {"type" => "bridge"})
    doc.root.elements["devices"].elements["interface"].add_element("mac", {"address" => macAddr})
    doc.root.elements["devices"].elements["interface"].add_element("source", {"bridge" => bridge})
  end

  doc.root.elements["devices"].add_element("input", {"type" => "mouse", "bus" => "ps2"})
  doc.root.elements["devices"].add_element("graphics", {"type" => "vnc", "port" => "-1", "listen" => "0.0.0.0"})

  doc.root.add_element("features")
  doc.root.elements["features"].add_element("acpi")
  doc.root.elements["features"].add_element("apic")

  serial = Element.new("serial")
  serial.add_attribute("type", "pty")
  serial.add_element("target", {"port" => "0"})
  doc.root.elements["devices"] << serial

  return doc
end

def set_vm_state(vm, state)
  vm.reload
  vm.state = state
  vm.save!
end

def set_vm_vnc_port(vm, xml_desc)
  doc = REXML::Document.new(xml_desc)
  attrib = REXML::XPath.match(doc, "//graphics/@port")
  if not attrib.empty?:
    vm.vnc_port = attrib.to_s.to_i
  end
  vm.save!
end

def find_vm(task, fail_on_nil_host_id = true)
  # find the matching VM in the vms table
  vm = task.vm

  if vm == nil
    raise "VM #{task.vm} not found for task #{task.id}"
  end

  if vm.host_id == nil && fail_on_nil_host_id
    raise "No host_id for VM " + vm.id.to_s
  end

  return vm
end

def set_vm_shut_down(vm)
  vm.host_id = nil
  vm.memory_used = nil
  vm.num_vcpus_used = nil
  vm.state = Vm::STATE_STOPPED
  vm.needs_restart = nil
  vm.vnc_port = nil
  vm.save!
end

