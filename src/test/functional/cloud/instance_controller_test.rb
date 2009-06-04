require 'test_helper'

class Cloud::InstanceControllerTest < ActionController::TestCase
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
  end

  def test_should_redirect_if_request_for_selected
    post(:index,{:submit_for_list => 'Show Selected'})
    assert_response :redirect
  end
end
