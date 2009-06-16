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
require 'storage_controller'

# Re-raise errors caught by the controller.
class StorageController; def rescue_action(e) raise e end; end

class StorageControllerTest < ActionController::TestCase
  fixtures :privileges, :roles, :permissions, :pools,
           :storage_volumes, :storage_pools

  def setup
    @controller = StorageController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @lun_1_id = storage_volumes(:ovirtpriv_storage_lun_1).id
    @ovirtpriv_storage_id = storage_pools(:corp_com_ovirtpriv_storage).id
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list
    get :list

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:storage_pools)
  end

  def test_show
    get :show, :id => @ovirtpriv_storage_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:storage_pool)
    assert assigns(:storage_pool).valid?
  end

  def test_new
    get :new, :hardware_pool_id => pools(:corp_com).id

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:storage_types)
  end

  def test_create_storage_controller
    hw_pool = HardwarePool.get_default_pool
    num_storage_volumes = StoragePool.count

    post :create, :storage_type => 'NFS', :storage_pool => { :hardware_pool => hw_pool, :ip_addr => '111.121.131.141', :export_path => '/tmp/path', :state => 'available', :capacity => 1024 }

    assert_response :success

    assert_equal num_storage_volumes + 1, StoragePool.count
  end

  def test_edit
    get :edit, :id => @ovirtpriv_storage_id

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:storage_pool)
    assert assigns(:storage_pool).valid?
  end

  def test_update
    post :update, :id => @ovirtpriv_storage_id
    assert_response :success
  end

  def test_destroy
    post :destroy, :id => @ovirtpriv_storage_id
    assert_response :success
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal 'Storage Pool was successfully deleted.', json['alert']
  end

  def test_no_perms_to_destroy
    xml_http_request :post, :destroy, :id => storage_pools(:corp_com_dev_nfs_ovirtnfs).id, :format => "json"
    assert_response :success
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal 'You have insufficient privileges to perform action.', json['alert']
  end

  #FIXME: write the code to make this a real test!
  def test_bad_id_on_destroy
#    post :destroy, :id => bad_id
#    assert_response :success
#    The controller needs to gracefully handle ActiveRecord::RecordNotFound,
#    which it does not right now.
  end
end
