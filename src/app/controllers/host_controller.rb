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

class HostController < ApplicationController

  include HostService

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => [:post, :put], :only => [ :create, :update ],
         :redirect_to => { :action => :list }
  verify :method => [:post, :delete], :only => :destroy,
         :redirect_to => { :action => :list }

  def index
    list
    respond_to do |format|
      format.html { render :action => 'list' }
      format.xml  { render :xml => @hosts.to_xml }
    end
  end

  def list
    svc_list(params)
  end

  def show
    svc_show(params[:id])
    respond_to do |format|
      format.html { render :layout => 'selection' }
      format.xml { render :xml => @host.to_xml(:include => [ :cpus ] ) }
    end
  end

  def quick_summary
    svc_show(id)
    render :layout => false
  end

  # retrieves data used by snapshot graphs
  def snapshot_graph
  end

  def addhost
    # FIXME: This probably should go into PoolService.svc_modify,
    # so that we have permission checks in only one place

    # Old pre_addhost
    @pool = Pool.find(params[:hardware_pool_id])
    @parent = @pool.parent
    set_perms(@pool)
    authorize_admin
    # Old addhost
    @hardware_pool = Pool.find(params[:hardware_pool_id])
    render :layout => 'popup'
  end

  def add_to_smart_pool
    @pool = SmartPool.find(params[:smart_pool_id])
    render :layout => 'popup'
  end

  # FIXME: We implement the standard controller actions, but catch
  # them in filters and kick out friendly warnings that you can't
  # perform them on hosts. Tat's overkill - the only way for a user
  # to get to these actions is with URL surgery or from a bug in the
  # application, both of which deserve a noisy error
  def new
  end

  def create
  end

  def edit
  end

  def update
  end

  def destroy
  end

  def host_action
    action = params[:action_type]
    if["disable", "enable", "clear_vms"].include?(action)
      self.send(action)
    else
      @json_hash[:alert]="invalid operation #{action}"
      @json_hash[:success]=false
      render :json => @json_hash
    end
  end

  def disable
    svc_enable(params[:id], "disabled")
    render :json => {
      :object => :host,
      :alert => "Host was successfully disabled",
      :success => true
    }
  end

  def enable
    svc_enable(params[:id], "enabled")
    render :json => {
      :object => :host,
      :alert => "Host was successfully enabled",
      :success => true
    }
  end

  def clear_vms
    svc_clear_vms(params[:id])
    render :json => {
      :object => :host,
      :alert => "Clear VMs action was successfully queued.",
      :success => true
    }
  end

  def edit_network
    svc_modify(params[:id])
    render :layout => 'popup'
  end

  def bondings_json
    svc_show(params[:id])
    bondings = @host.bondings
    render :json => bondings.collect{ |x| {:id => x.id, :name => x.name} }
  end

  private
  #filter methods
  def pre_new
    flash[:notice] = 'Hosts may not be edited via the web UI'
    redirect_to :controller => 'hardware', :action => 'show', :id => params[:hardware_pool_id]
  end
  def pre_create
    flash[:notice] = 'Hosts may not be edited via the web UI'
    redirect_to :controller => 'dashboard'
  end
  def pre_edit
    @host = Host.find(params[:id])
    flash[:notice] = 'Hosts may not be edited via the web UI'
    redirect_to :action=> 'show', :id => @host
  end
  def pre_show
    @host = Host.find(params[:id])
    set_perms(@host.hardware_pool)
  end


end
