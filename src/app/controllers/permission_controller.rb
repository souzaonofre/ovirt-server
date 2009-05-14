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

class PermissionController < ApplicationController
  include PermissionService
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create ],
         :redirect_to => { :controller => 'dashboard' }

  def show
    svc_show(params[:id])
  end

  def new
    svc_new(params[:pool_id])
    @users = Account.names(@permission.pool.permissions.collect{ |permission|
                             permission.uid })
    @roles = Role.find(:all).collect{ |role| [role.name, role.id] }
    render :layout => 'popup'
  end

  def create
    alert = svc_create(params[:permission])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  def update_roles
    permission_ids = params[:permission_ids].split(",")
    role_id = params[:role_id]
    successes = []
    failures = {}
    permission_ids.each do |permission_id|
      begin
        svc_update_role(permission_id, role_id)
        successes << @permission
      # PermissionError and ActionError are expected
      rescue Exception => ex
        failures[@permission.nil? permission_id : @permission] = ex.message
      end
    end
    unless failures.empty?
      raise PartialSuccessError.new("Update roles for some Permission records",
                                    failures, successes)
    end
    render :json => { :object => "permission", :success => true,
                      :alert => "Permission roles were successfully updated." }
  end

  def delete
    permission_ids = params[:permission_ids].split(",")
    successes = []
    failures = {}
    permission_ids.each do |permission_id|
      begin
        svc_destroy(permission_id)
        successes << @permission
      # PermissionError expected
      rescue Exception => ex
        failures[@permission.nil? permission_id : @permission] = ex.message
      rescue Exception => ex
        failures[@permission] = ex.message
      end
    end
    unless failures.empty?
      raise PartialSuccessError.new("Delete failed for some Permission records",
                                    failures, successes)
    end
    render :json => { :object => "permission", :success => true,
                      :alert => "Permission records were successfully deleted." }
  end

  def destroy
    alert = svc_destroy(params[:id])
    render :json => { :object => "vm", :success => true, :alert => alert  }
  end

  # FIXME: remove these when service transition is complete. these are here
  # to keep from running permissions checks and other setup steps twice
  def tmp_pre_update
  end
  def tmp_authorize_admin
  end
end
