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
require 'host_controller'

# Re-raise errors caught by the controller.
class HostController; def rescue_action(e) raise e end; end

class HostControllerTest < Test::Unit::TestCase
  fixtures :hosts, :pools, :privileges, :roles, :permissions

  def setup
    @controller = HostController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @host_id = hosts(:prod_corp_com).id
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

    assert_not_nil assigns(:hosts)
  end

  def test_show
    get :show, :id => @host_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:host)
    assert assigns(:host).valid?
  end

  def test_disable_host
    post :host_action, :action_type => 'disable', :id => @host_id
    assert_response :success
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal 'Host was successfully disabled', json['alert']
  end
end
