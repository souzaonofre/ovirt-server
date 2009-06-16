#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>,
#            Jason Guiditta <jguiditt@redhat.com>
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

require File.dirname(__FILE__) + '/../test_helper'

class VmTest < ActiveSupport::TestCase
  fixtures :vms
  fixtures :pools

  def setup
    @vm_name = "Test"
    @no_cobbler_provisioning = "#{@vm_name}"
    @cobbler_image_provisioning =
      "#{Vm::IMAGE_PREFIX}@#{Vm::COBBLER_PREFIX}#{Vm::PROVISIONING_DELIMITER}#{@vm_name}"
    @cobbler_profile_provisioning =
      "#{Vm::PROFILE_PREFIX}@#{Vm::COBBLER_PREFIX}#{Vm::PROVISIONING_DELIMITER}#{@vm_name}"

    @vm = Vm.new(
       :uuid => '00000000-1111-2222-3333-444444444444',
       :description => 'foobar',
       :num_vcpus_allocated => 1,
       :boot_device => 'hd',
       :memory_allocated_in_mb => 1,
       :memory_allocated => 1024,
       :vnic_mac_addr => '11:22:33:44:55:66')

    @vm.vm_resource_pool = pools(:corp_com_production_vmpool)
  end

  def test_valid_fails_with_bad_uuid
       @vm.uuid = 'foobar'
       flunk "Vm must specify valid uuid" if @vm.valid?
  end

  def test_valid_fails_without_description
       @vm.description = ''
       flunk 'Vm must specify description' if @vm.valid?
  end

  def test_valid_fails_without_num_vcpus_allocated
       @vm.num_vcpus_allocated = nil
       flunk 'Vm must specify num_vcpus_allocated' if @vm.valid?
  end

  def test_valid_fails_without_boot_device
       @vm.boot_device = ''
       flunk 'Vm must specify boot_device' if @vm.valid?
  end


  def test_valid_fails_without_memory_allocated
       @vm.memory_allocated = ''
       flunk 'Vm must specify memory_allocated' if @vm.valid?
  end


  def test_valid_fails_without_memory_allocated_in_mb
       @vm.memory_allocated_in_mb = ''
       flunk 'Vm must specify memory_allocated_in_mb' if @vm.valid?
  end

  def test_valid_fails_without_vnic_mac_addr
       @vm.vnic_mac_addr = ''
       flunk 'Vm must specify vnic_mac_addr' if @vm.valid?
  end

  def test_valid_fails_without_vm_resources_pool_id
       @vm.vm_resource_pool_id = ''
       flunk 'Vm must specify vm_resources_pool_id' if @vm.valid?
  end

  def test_valid_fails_with_bad_needs_restart
       @vm.needs_restart = 5
       flunk 'Vm must specify valid needs_restart' if @vm.valid?
  end

  def test_valid_fails_with_bad_state
       @vm.state = 'foobar'
       flunk 'Vm must specify valid state' if @vm.valid?
  end

  # ensure duplicate forward_vnc_ports cannot exist
  def test_invalid_without_unique_forward_vnc_port
     vm = vms(:production_mysqld_vm)
     vm.forward_vnc = true
     vm.forward_vnc_port = 1234 # duplicate
     assert !vm.valid?, "forward vnc port must be unique"
  end

  # ensure bad forward_vnc_ports cannot exist
  def test_invalid_without_bad_forward_vnc_port
     vm = vms(:production_mysqld_vm)
     vm.forward_vnc = true
     vm.forward_vnc_port = 1 # too small
     assert !vm.valid?, "forward vnc port must be >= 5900"
  end

  # Ensures that, if the VM does not contain the Cobbler prefix, that it
  # does not claim to be a Cobbler VM.
  #
  def test_uses_cobbler_without_cobbler_prefix
    vm = Vm.new

    vm.provisioning_and_boot_settings=@no_cobbler_provisioning

    flunk "VM is not a Cobbler provisioned one." if vm.uses_cobbler?
    assert_equal @vm_name, vm.provisioning, "Wrong name reported."
  end

  # Ensures that the VM reports that it uses Cobbler if the provisioning
  # is for a Cobbler profile.
  #
  def test_uses_cobbler_with_cobbler_profile
    vm = Vm.new

    vm.provisioning_and_boot_settings = @cobbler_profile_provisioning

    flunk "VM did not report that it's Cobbler provisioned." unless vm.uses_cobbler?
    assert_equal Vm::PROFILE_PREFIX,
      vm.cobbler_type,
      "Wrong cobbler type reported."
    assert_equal @vm_name,
      vm.cobbler_name,
      "Wrong name reported."
  end

  # Ensures that the VM reports that it uses Cobbler if the provisioning
  # is for a Cobbler image.
  #
  def test_uses_cobbler_with_cobbler_image
    vm = Vm.new

    vm.provisioning_and_boot_settings = @cobbler_image_provisioning

    flunk "VM did not report that it's Cobbler provisioned." unless vm.uses_cobbler?
    assert_equal Vm::IMAGE_PREFIX,
      vm.cobbler_type,
      "Wrong cobbler type reported."
    assert_equal @vm_name,
      vm.cobbler_name,
      "Wrong name reported."
  end

  # Ensures that the right value is used when requesting the cobbler system
  # name for a VM backed by Cobbler.
  #
  def test_cobbler_system_name
    @vm = Vm.new
    @vm.provisioning_and_boot_settings = @cobbler_profile_provisioning
    @vm.uuid = "oicu812"

    assert_equal @vm.cobbler_system_name, @vm.uuid,
      "VMs should be using the UUID as their Cobbler system name."
  end

  def test_get_pending_state
    assert_equal 'stopped', vms(:production_httpd_vm).get_pending_state
  end

  def test_get_action_list_with_no_user
    empty_array = []
    assert_equal(empty_array, vms(:production_httpd_vm).get_action_list)
  end

  def test_queue_action_returns_false_with_invalid_action
    assert_equal(false, vms(:production_httpd_vm).queue_action('ovirtadmin', 'stop_vm'))
  end

  def test_valid_action_with_invalid_param
    assert_equal(false, vms(:production_httpd_vm).valid_action?('stop_vm'))
  end

  # Ensure valid_action? returns true
  def test_valid_action_with_valid_param
    assert_equal(true, vms(:production_httpd_vm).valid_action?('shutdown_vm'))
  end

  def test_paginated_results
    assert_equal 5, Vm.paged_with_perms('ovirtadmin', Privilege::VIEW, 1, 'vms.id').size
  end

  def test_paginated_results_sorting
    vms = Vm.paged_with_perms('ovirtadmin', Privilege::VIEW, 1, 'calc_uptime')
    assert_equal(5, vms.size)
    assert_equal('00:00:00',vms[0].calc_uptime)
  end
end
