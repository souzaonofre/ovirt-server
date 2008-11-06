
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
require 'permission_controller'

# Re-raise errors caught by the controller.
class PermissionController; def rescue_action(e) raise e end; end

class PermissionControllerTest < Test::Unit::TestCase
  fixtures :permissions, :pools

  def setup
    @controller = PermissionController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @permission_id = permissions(:ovirtadmin_default).id
  end

  def test_show
    get :show, :id => @permission_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:permission)
    assert assigns(:permission).valid?
  end

  def test_new
    get :new, :pool_id => pools(:default).id

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:permission)
  end

  def test_create
    num_permissions = Permission.count
    post :create, :permission => { :user_role => 'Administrator',
                                    :uid => 'admin',
                                    :pool_id => pools(:corp_com_production_vmpool).id}
    assert_response :success
    assert_equal num_permissions + 1, Permission.count
  end

  def test_destroy
    post :destroy, :id => @permission_id
    assert_response :redirect
    assert_redirected_to :controller => 'hardware', :action => 'show', :id => pools(:default).id
    assert_equal "<strong>ovirtadmin</strong> permissions were revoked successfully" , flash[:notice]
  end

  def test_no_perms_to_destroy
    post :destroy, :id => permissions(:ovirtadmin_corp_com_qa_pool).id
    assert_response :redirect
    assert_redirected_to :controller => 'hardware', :action => 'show', :id => pools(:corp_com_qa).id
    assert_equal "You do not have permission to delete this permission record" , flash[:notice]
  end

  #FIXME: write the code to make this a real test!
  def test_bad_id_on_destroy
#    post :destroy, :id => bad_id
#    assert_response :success
#    The controller needs to gracefully handle ActiveRecord::RecordNotFound,
#    which it does not right now.
  end
end
