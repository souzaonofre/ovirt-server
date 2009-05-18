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
require 'quota_controller'

# Re-raise errors caught by the controller.
class QuotaController; def rescue_action(e) raise e end; end

class QuotaControllerTest < Test::Unit::TestCase
  fixtures :quotas, :pools

  def setup
    @controller = QuotaController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @quota_id = quotas(:default_quota).id
  end

  def test_show
    get :show, :id => @quota_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:quota)
    assert assigns(:quota).valid?
  end

  def test_new
    get :new, :pool_id => pools(:default).id

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:quota)
  end

  def test_create
    num_quotas = Quota.count

    post :create, :quota => { :pool_id => pools(:default).id }

    assert_response :success

    assert_equal num_quotas + 1, Quota.count
  end

  def test_edit
    get :edit, :id => @quota_id

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:quota)
    assert assigns(:quota).valid?
  end

  def test_update
    post :update, :id => @quota_id
    assert_response :success
  end

  def test_destroy
    post :destroy, :id => @quota_id
    assert_response :success
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal 'Quota was successfully deleted.', json['alert']
  end

  def test_not_destroyed
    assert true  #How do we make it return failure message?
  end

  def test_no_perms_to_destroy
    post :destroy, :id => quotas(:corp_com_dev_quota).id, :format => "json"
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
