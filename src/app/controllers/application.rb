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

  # General error handlers, must be in order from least specific
  # to most specific
  rescue_from Exception, :with => :handle_general_error
  rescue_from PermissionError, :with => :handle_perm_error
  rescue_from PartialSuccessError, :with => :handle_partial_success_error

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
      handle_error(:message => msg,
                   :title => "Access Denied", :status => :forbidden)
      false
    else
      true
    end
  end

  def handle_perm_error(error)
    handle_error(:error => error, :status => :forbidden,
                 :title => "Access denied")
  end

  def handle_partial_success_error(error)
    failures_arr = error.failures.collect do |resource, reason|
      resource.display_name + ": " + reason
    end
    handle_error(:error => error, :status => :ok,
                 :message => error.message + ": " + failures_arr.join(", "),
                 :title => "Some actions failed")
  end

  def handle_general_error(error)
    handle_error(:error => error, :status => :internal_server_error,
                 :title => "Internal Server Error")
  end

  def handle_error(hash)
    log_error(hash[:error])
    msg = hash[:message] || hash[:error].message
    title = hash[:title] || "Internal Server Error"
    status = hash[:status] || :internal_server_error
    respond_to do |format|
      format.html { html_error_page(title, msg) }
      format.json { render :json => json_error_hash(msg, status) }
      format.xml { render :xml => xml_errors(msg), :status => status }
    end
  end

  def html_error_page(title, msg)
    @title = title
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

  private
  def json_error_hash(msg, status)
    json = {}
    json[:success] = (status == :ok)
    json.merge!(instance_errors)
    # There's a potential issue here: if we add :errors for an object
    # that the view won't generate inline error messages for, the user
    # won't get any indication what the error is. But if we set :alert
    # unconditionally, the user will get validation errors twice: once
    # inline in the form, and once in the flash
    json[:alert] = msg unless json[:errors]
    return json
  end

  def xml_errors(msg)
    xml = {}
    xml[:message] = msg
    xml.merge!(instance_errors)
    return xml
  end

  def instance_errors
    hash = {}
    instance_variables.each do |ivar|
      val = instance_variable_get(ivar)
      if val && val.respond_to?(:errors) && val.errors.size > 0
        hash[:object] = ivar[1, ivar.size]
        hash[:errors] ||= []
        hash[:errors] += val.errors.localize_error_messages.to_a
      end
    end
    return hash
  end
end
