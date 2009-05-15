# Copyright (C) 2008 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
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
#

class NetworkController < ApplicationController
  include NetworkService
   ########################## Networks related actions

  def list
    svc_list
    respond_to do |format|
      format.html {
        render :layout => 'tabs-and-content' if params[:ajax]
        render :layout => 'help-and-content' if params[:nolayout]
      }
      format.xml {
        render :xml => @pool.to_xml(XML_OPTS)
      }
    end
  end

  def networks_json
    svc_list
    json_list(@networks, [:id, :name, :type, [:boot_type, :label]])
  end

  def show
    svc_show(params[:id])
    respond_to do |format|
      format.html { render :layout => 'selection' }
      format.xml { render :xml => @network.to_xml }
    end
  end

  def new
    svc_new
    @boot_types = BootType.find(:all)
    @usage_types = Usage.find(:all)
    render :layout => 'popup'
  end

  def create
    alert = svc_create(params[:network])
    render :json => { :object => "network", :success => true, :alert => alert  }
  end

  def edit
    svc_modify(params[:id])
    @usage_types = Usage.find(:all)
    @boot_types = BootType.find(:all)
    render :layout => 'popup'
  end

  def update
    alert = svc_update(params[:id], params[:network])
    render :json => { :object => "network", :success => true, :alert => alert }
  end

  def delete
    network_ids = params[:network_ids].split(",")
    successes = []
    failures = {}
    network_ids.each do |network_id|
      begin
        svc_destroy(network_id)
        successes << @network
      # PermissionError and ActionError are expected
      rescue Exception => ex
        failures[@network.nil? network_id : @network] = ex.message
      end
    end
    unless failures.empty?
      raise PartialSuccessError.new("Delete failed for some networks",
                                    failures, successes)
    end
    render :json => { :object => "network", :success => true,
                      :alert => "Networks were successfully deleted." }
  end

  def edit_network_ip_addresses
    svc_modify(params[:id])
    render :layout => 'popup'
  end


   ########################## Ip Address related actions

  def ip_addresses_json
    svc_ip_addresses(params[:parent_type], params[:id])
    ip_addresses_json = []
    @ip_addresses.each{ |x|
          ip_addresses_json.push({:id => x.id, :name => x.address}) }
    render :json => ip_addresses_json
   end

   def new_ip_address
    svc_ip_addresses(params[:parent_type], params[:id])
    render :layout => false
   end

  def create_ip_address
    alert = svc_create_ip_address(params[:ip_address])
    render :json => {:object => "ip_address", :success => true, :alert => alert}
  end

  def edit_ip_address
    svc_modify_ip_address(params[:parent_type], params[:id])
    render :layout => false
  end

  def update_ip_address
    alert = svc_update_ip_address(params[:id], params[:ip_address])
    render :json => {:object => "ip_address", :success => true, :alert => alert}
  end

  def destroy_ip_address
    alert = svc_destroy_ip_address(params[:id])
    render :json => {:object => "ip_address", :success => true, :alert => alert}
  end

   ########################## NICs related actions

  def edit_nic
    svc_modify_nic(params[:id])
    render :layout => false
  end

  def update_nic
    alert = svc_update_nic(params[:id], params[:nic], params[:ip_address])
    render :json => { :object => "nic", :success => true, :alert => alert}
  end

   ########################## Bonding related actions

  def new_bonding
    raise ActionError.new("Host is required") unless params[:host_id]
    svc_new_bonding(params[:host_id])
    render :layout => false
   end

  def create_bonding
    alert = svc_create_bonding(params[:bonding], params[:ip_address])
    render :json => { :object => "bonding", :success => true, :alert => alert}
  end

  def edit_bonding
    svc_modify_bonding(params[:id])
    render :layout => false
  end

  def update_bonding
    alert = svc_update_bonding(params[:id], params[:bonding], params[:ip_address])
    render :json => { :object => "bonding", :success => true, :alert => alert}
  end

  def destroy_bonding
    alert = svc_destroy_bonding(params[:id])
    render :json => {:object => "bonding", :success => true, :alert => alert}
  end

  protected
  # FIXME: remove these when service transition is complete. these are here
  # to keep from running permissions checks and other setup steps twice
  def tmp_pre_update
  end
  def tmp_authorize_admin
  end

end
