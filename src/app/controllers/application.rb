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

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.


class ApplicationController < ActionController::Base
  # FIXME: once all controller classes include this, remove here
  include ApplicationService

  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_ovirt_session_id'
  init_gettext "ovirt"
  layout :choose_layout

  # FIXME: once service layer is complete, the following before_filters will be
  # removed as their functionality has been moved to the service layer
  # pre_create
  # pre_edit will remain only for :edit, not :update or :destroy
  # pre_show
  # authorize_admin will remain only for :new, :edit
  before_filter :pre_new, :only => [:new]
  before_filter :pre_create, :only => [:create]
  before_filter :pre_edit, :only => [:edit]
  # the following is to facilitate transition to service layer
  before_filter :tmp_pre_update, :only => [:update, :destroy]
  before_filter :pre_show, :only => [:show]
  before_filter :authorize_admin, :only => [:new, :edit]
  before_filter :tmp_authorize_admin, :only => [:create, :update, :destroy]
  before_filter :is_logged_in, :get_help_section


  def choose_layout
    if(params[:component_layout])
      return (ENV["RAILS_ENV"] != "production")?'components/' << params[:component_layout]:'redux'
    end
    return 'redux'
  end

  def is_logged_in
    redirect_to(:controller => "login", :action => "login") unless get_login_user
  end

  def get_help_section
      help = HelpSection.find(:first, :conditions => [ "controller = ? AND action = ?", controller_name, action_name ])
      @help_section = help ? help.section : ""
      if @help_section.index('#')
        help_sections = @help_section.split('#')
        @help_section = help_sections[0]
        @anchor = help_sections[1]
      else
        @help_section = @help_section
        @anchor = ""
      end
  end

  def get_login_user
    (ENV["RAILS_ENV"] == "production") ? session[:user] : "ovirtadmin"
  end

  protected
  # permissions checking

  def pre_new
  end
  def pre_edit
  end

  # FIXME: remove these when service layer transition is complete
  def tmp_pre_update
    pre_edit
  end
  def tmp_authorize_admin
    authorize_admin
  end
  def pre_create
  end
  def pre_show
  end

  def authorize_view(msg=nil)
    authorize_action(Privilege::VIEW,msg)
  end
  def authorize_user(msg=nil)
    authorize_action(Privilege::VM_CONTROL,msg)
  end
  def authorize_admin(msg=nil)
    authorize_action(Privilege::MODIFY,msg)
  end
  def authorize_action(privilege, msg=nil)
    msg ||= 'You have insufficient privileges to perform action.'
    unless authorized?(privilege)
      handle_auth_error(msg)
      false
    else
      true
    end
  end
  def handle_auth_error(msg)
    respond_to do |format|
      format.html do
        html_error_page(msg)
      end
      format.json do
        @json_hash ||= {}
        @json_hash[:success] = false
        @json_hash[:alert] = msg
        render :json => @json_hash
      end
      format.xml { head :forbidden }
    end
  end
  def html_error_page(msg)
    @title = "Access denied"
    @errmsg = msg
    @ajax = params[:ajax]
    @nolayout = params[:nolayout]
    if @ajax
      render :template => 'layouts/popup-error', :layout => 'tabs-and-content'
    elsif @nolayout
      render :template => 'layouts/popup-error', :layout => 'help-and-content'
    else
      render :template => 'layouts/popup-error', :layout => 'popup'
    end
  end
  # don't define find_opts for array inputs
  def json_hash(full_items, attributes, arg_list=[], find_opts={}, id_method=:id)
    page = params[:page].to_i
    paginate_opts = {:page => page,
                     :order => "#{params[:sortname]} #{params[:sortorder]}",
                     :per_page => params[:rp]}
    arg_list << find_opts.merge(paginate_opts)
    item_list = full_items.paginate(*arg_list)
    json_hash = {}
    json_hash[:page] = page
    json_hash[:total] = item_list.total_entries
    json_hash[:rows] = item_list.collect do |item|
      item_hash = {}
      item_hash[:id] = item.send(id_method)
      item_hash[:cell] = attributes.collect do |attr|
        if attr.is_a? Array
          value = item
          attr.each { |attr_item| value = (value.nil? ? nil : value.send(attr_item))}
          value
        else
          item.send(attr)
        end
      end
      item_hash
    end
    json_hash
  end

  # json_list is a helper method used to format data for paginated flexigrid tables
  #
  # FIXME: what is the intent of this comment? don't define find_opts for array inputs
  def json_list(full_items, attributes, arg_list=[], find_opts={}, id_method=:id)
    render :json => json_hash(full_items, attributes, arg_list, find_opts, id_method).to_json
  end

  def json_error(obj_type, obj, exception)
    json_hash = { :object => obj_type, :success => false}
    json_hash[:errors] = obj.errors.localize_error_messages.to_a if obj
    json_hash[:alert] = exception.message if obj.errors.size == 0
    render :json => json_hash
  end

end
