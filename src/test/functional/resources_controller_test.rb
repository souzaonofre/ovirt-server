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
require 'resources_controller'

# Re-raise errors caught by the controller.
class ResourcesController; def rescue_action(e) raise e end; end

class ResourcesControllerTest < ActionController::TestCase
  fixtures :permissions, :pools

  def setup
    @controller = ResourcesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index
    get :index
    assert_response :success
    assert_not_nil assigns(:vm_resource_pools)
  end

  def test_new
    get :new, :parent_id => pools(:default).id
    assert_response :success
  end

  def test_create
    assert_difference('VmResourcePool.count') do
      post :create, :vm_resource_pool => { :name => 'foo_resource_pool' }, :parent_id => pools(:default).id
    end

    assert_response :success
  end

  def test_show
    get :show, :id => pools(:corp_com_production_vmpool).id
    assert_response :success
  end

  def test_edit
    get :edit, :id => pools(:corp_com_production_vmpool).id
    assert_response :success
  end

  def test_update
    put :update, :id => pools(:corp_com_production_vmpool).id, :vm_resource_pool => { }
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_destroy_valid_pool
    post :destroy, :id => pools(:corp_com_production_vmpool).id
    assert_response :success
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal 'Virtual Machine Pool was successfully deleted.', json['alert']
  end

end
