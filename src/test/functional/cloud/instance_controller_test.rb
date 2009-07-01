#
# Copyright (C) 2008 Red Hat, Inc.
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

require File.dirname(__FILE__) + '/../../test_helper'

class Cloud::InstanceControllerTest < ActionController::TestCase

  include ServiceModuleHelper
  fixtures :vms, :tasks
  def setup
    @controller = Cloud::InstanceController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_show_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:vms)
    assert_not_nil assigns(:user)
    assert_equal({}, flash, "flash object is not empty!")
    assert_equal(true, flash.empty?)
    assert_select "#notification", false, "This page must contain no notification block"
  end

  def test_should_redirect_if_form_submitted
    post(:index,{:submit_for_list => 'Show Selected'})
    assert_redirected_to :action => :index
    #TODO: since this is a redirect, it returns a 302 and nil template,
    # would be good to figure out how to get the actual result returned to
    # browser so we can do an assert_select
  end

  def test_add_valid_task
    post(:index,{:submit_for_list => 'Shutdown', :ids => [vms(:production_mysqld_vm).id]})
    assert_equal('shutdown_vm submitted.', flash[:notice])
    assert_redirected_to :action => :index, :ids => vms(:production_mysqld_vm).id
  end

  def test_add_invalid_task
    post(:index,{:submit_for_list => 'Shutdown',
                 :ids => [vms(:production_mysqld_vm).id,vms(:production_httpd_vm).id]})
    expected_failures = {:summary => "Your request to shutdown_vm encountered the following errors: ",
                         :failures => {vms(:production_httpd_vm).description => "shutdown_vm cannot be performed on this vm."},
                         :successes => ["#{vms(:production_mysqld_vm).description}: shutdown_vm was successfully queued."]}
    assert_equal(expected_failures, flash[:error])
    assert_redirected_to :action => :index, :ids => [vms(:production_mysqld_vm).id,vms(:production_httpd_vm).id]
  end

  def test_add_task_no_perms_for_some_vms
    post(:index,{:submit_for_list => 'Shutdown',
                 :ids => [vms(:production_mysqld_vm).id,vms(:corp_com_qa_postgres_vm).id]})
    expected_failures = {:summary => "Your request to shutdown_vm encountered the following errors: ",
                         :failures => {vms(:corp_com_qa_postgres_vm).description => "You have insufficient privileges to perform action."},
                         :successes => ["#{vms(:production_mysqld_vm).description}: shutdown_vm was successfully queued."]}
    assert_equal(expected_failures, flash[:error])
    assert_redirected_to :action => :index, :ids => [vms(:production_mysqld_vm).id,vms(:corp_com_qa_postgres_vm).id]
  end

  # Make sure we get warning back if no instance was chosen to perform an action on.
  def test_no_instance_chosen
    post(:index,{:submit_for_list => 'Shutdown'})
    assert_equal("You must select at least one instance to perform an action.", flash[:warning])
  end
end
