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

class QuotaController < ApplicationController
  include QuotaService
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :controller => 'dashboard' }

  def show
    svc_show(params[:id])
  end

  def new
    svc_new(params[:pool_id])
    render :layout => 'popup'    
  end

  def create
    alert = svc_create(params[:quota])
    render :json => { :object => "quota", :success => true, :alert => alert }
  end

  def edit
    svc_modify(params[:id])
    render :layout => 'popup'    
  end

  def update
    alert = svc_update(params[:id], params[:quota])
    render :json => { :object => "quota", :success => true, :alert => alert }
  end

  def destroy
    alert = svc_destroy(params[:id])
    render :json => { :object => "quota", :success => true, :alert => alert }
  end

  # FIXME: remove these when service transition is complete. these are here
  # to keep from running permissions checks and other setup steps twice
  def tmp_pre_update
  end
  def tmp_authorize_admin
  end

end
