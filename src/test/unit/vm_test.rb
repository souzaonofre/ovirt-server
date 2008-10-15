# 
# Copyright (C) 2008 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>
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

class VmTest < Test::Unit::TestCase
  fixtures :vms

  def setup
    @vm_name = "Test"
    @no_cobbler_provisioning = "#{@vm_name}"
    @cobbler_image_provisioning =
      "#{Vm::IMAGE_PREFIX}@#{Vm::COBBLER_PREFIX}#{Vm::PROVISIONING_DELIMITER}#{@vm_name}"
    @cobbler_profile_provisioning =
      "#{Vm::PROFILE_PREFIX}@#{Vm::COBBLER_PREFIX}#{Vm::PROVISIONING_DELIMITER}#{@vm_name}"
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
end
