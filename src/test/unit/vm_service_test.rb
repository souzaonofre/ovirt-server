#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Jason Guiditta <jguiditt@redhat.com>
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

class VmServiceTest < ActiveSupport::TestCase

  include ServiceModuleHelper
  include VmService
  fixtures :vms

  def setup
    set_login_user('ovirtadmin')
  end

  # Ensure correct message is returned for a valid action requested
  # by a user with the proper permissions
  def test_svc_vm_action_valid_user
    assert_equal("#{vms(:production_mysqld_vm).description}: shutdown_vm was successfully queued.",
      svc_vm_action(vms(:production_mysqld_vm).id, 'shutdown_vm', nil))
  end

  # Ensure that if a non-existant action is passed in, ActionError
  # is thrown
  def test_svc_vm_action_invalid_action
    assert_raise ActionError do
      svc_vm_action(vms(:production_httpd_vm).id, 'stop_vm', nil)
    end
  end

  # Ensure that if a user with the wrong permissions is passed in,
  # PermissionError is thrown
  def test_svc_vm_action_invalid_user
    set_login_user('fred')
    assert_raise PermissionError do
      svc_vm_action(vms(:production_mysqld_vm).id, 'shutdown_vm', nil)
    end
  end

  # Ensure that if an invalid state change for a vm is requested,
  # ActionError is thrown
  def test_svc_vm_action_invalid_state_change
    assert_raise ActionError do
      svc_vm_action(vms(:production_httpd_vm).id, 'shutdown_vm', nil)
    end
  end

  # If only one vm was passed into svc_vm_actions, and that action cannot
  # be performed, ActionError should be returned
  def test_failed_single_vm_returns_partial_success_error
    assert_raise PartialSuccessError do
      svc_vm_actions(vms(:production_httpd_vm).id, 'shutdown_vm', nil)
    end
  end

  # If multiple vms were passed into svc_vm_actions, and one or more (but
  # not all) actions cannot be performed, PartialSuccessError should be returned
  def test_failed_multiple_vms_return_partial_success
    assert_raise PartialSuccessError do
      svc_vm_actions([vms(:production_httpd_vm).id,
                      vms(:production_mysqld_vm).id,
                      vms(:production_ftpd_vm).id], 'shutdown_vm', nil)
    end
  end

  # Ensure we receive the expected success message if all actions succeed
  # (should be the same message if one or more, so we have one test for
  # each of those cases)
  def test_success_message_from_single_vm
    assert_equal("shutdown_vm successful.",
      svc_vm_actions(vms(:production_mysqld_vm).id, 'shutdown_vm', nil))
  end

  # Ensure we receive the expected success message if all actions succeed
  # (should be the same message if one or more, so we have one test for
  # each of those cases)
  def test_success_message_for_multiple_vms
    assert_equal("shutdown_vm successful.",
      svc_vm_actions([vms(:production_postgresql_vm).id,
                      vms(:production_mysqld_vm).id,
                      vms(:foobar_prod1_vm).id], 'shutdown_vm', nil))
  end

  # Ensure that if a non-existant action is passed in, PartialSuccessError
  # is thrown
  def test_svc_vm_actions_invalid_action
    assert_raise PartialSuccessError do
      svc_vm_actions(vms(:production_httpd_vm).id, 'stop_vm', nil)
    end
  end

  # Ensure we receive the expected success message if all actions succeed
  # (should be the same message if one or more, so we have one test for
  # each of those cases)
  def test_success_message_from_single_vm_with_less_privileged_user
    set_login_user('testuser')
    assert_equal("shutdown_vm successful.",
      svc_vm_actions(vms(:corp_com_qa_postgres_vm).id, 'shutdown_vm', nil))
  end

  # Ensure that if a user with the wrong permissions is passed in,
  # PartialSuccessError is thrown.  This allows some vms to still pass
  # while others with wrong perms fail.
  def test_svc_vm_actions_invalid_user
    set_login_user('testuser')
    assert_raise PartialSuccessError do
      svc_vm_actions([vms(:corp_com_qa_postgres_vm).id,
                      vms(:production_mysqld_vm).id], 'shutdown_vm', nil)
    end
  end

  # Ensure that if a user with the wrong permissions is passed in,
  # PartialSuccessError contains the message of success and permission error.
  def test_error_for_svc_vm_actions_invalid_user
    set_login_user('testuser')
    actual_error = nil
    expected_error = PartialSuccessError.new(
                    "Your request to shutdown_vm encountered the following errors: ",
                    {vms(:production_mysqld_vm).description => "You have insufficient privileges to perform action."},
                    ["#{vms(:corp_com_qa_postgres_vm).description}: shutdown_vm was successfully queued."])

    begin
      svc_vm_actions([vms(:corp_com_qa_postgres_vm).id,
                      vms(:production_mysqld_vm).id], 'shutdown_vm', nil)
    rescue Exception => ex
      actual_error = ex
    end
    assert_equal expected_error.message, actual_error.message
    assert_equal expected_error.failures, actual_error.failures
    assert_equal expected_error.successes, actual_error.successes
  end
end
