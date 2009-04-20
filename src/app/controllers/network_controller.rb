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
   ########################## Networks related actions

  before_filter :pre_list, :only => [:list]

   def authorize_admin
     # TODO more robust permission system
     #  either by subclassing network from pool
     #  or by extending permission model to accomodate
     #  any object
     @default_pool = HardwarePool.get_default_pool
     set_perms(@default_pool)
     super('You do not have permission to access networks')
   end

   def pre_list
     @networks = Network.find(:all)
     authorize_admin
   end

   def list
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
      json_list(Network.find(:all), [:id, :name, :type, [:boot_type, :label]])
   end

   def pre_show
     @network = Network.find(params[:id])
     authorize_admin
   end

   def show
    respond_to do |format|
      format.html { render :layout => 'selection' }
      format.xml { render :xml => @network.to_xml }
    end
   end

   def new
    @boot_types = BootType.find(:all)
    @usage_types = Usage.find(:all)
    render :layout => 'popup'
   end

   def create
    begin
     @network = PhysicalNetwork.new(params[:network]) if params[:network][:type] == 'PhysicalNetwork'
     @network = Vlan.new(params[:network]) if params[:network][:type] == 'Vlan'
     @network.save!
     alert = "Network was successfully created."
     render :json => { :object => "network", :success => true,
                       :alert => alert  }
    rescue
     render :json => { :object => "network", :success => false,
                        :errors =>
                        @network.errors.localize_error_messages.to_a }
    end
   end

   def edit
    @network = Network.find(params[:id])
    @usage_types = Usage.find(:all)
    @boot_types = BootType.find(:all)
    render :layout => 'popup'
   end

   def update
    begin
     @network = Network.find(params[:id])
     if @network.type == 'PhysicalNetwork'
       @network = PhysicalNetwork.find(params[:id])
     else
       @network = Vlan.find(params[:id])
     end

     @network.usages.delete_all
     @network.update_attributes!(params[:network])

     alert = "Network was successfully updated."
     render :json => { :object => "network", :success => true,
                       :alert => alert  }
    rescue Exception => e
     render :json => { :object => "network", :success => false,
                        :errors =>
                        @network.errors.localize_error_messages.to_a }
    end
   end

   def delete
     failed_networks = []
     networks_ids_str = params[:network_ids]
     network_ids = networks_ids_str.split(",").collect {|x| x.to_i}
     network_ids.each{ |x|
       network = Network.find(x)
       unless network.type.to_s == 'Vlan' &&
               Vlan.find(x).bondings.size != 0 ||
              network.type.to_s == 'PhysicalNetwork' &&
               PhysicalNetwork.find(x).nics.size != 0
         begin
            Network.destroy(x)
         rescue
           failed_networks.push x
         end
       else
         failed_networks.push x
       end
     }
     if failed_networks.size == 0
      render :json => { :object => "network",
                        :success => true,
                        :alert => "Successfully deleted networks" }
     else
      render :json => { :object => "network",
                        :success => false,
                        :alert => "Failed deleting " +
                                  failed_networks.size.to_s +
                             " networks due to existing bondings/nics" }
     end
   end

   def edit_network_ip_addresses
    @network = Network.find(params[:id])
    render :layout => 'popup'
   end


   ########################## Ip Address related actions

   def ip_addresses_json
    @parent_type = params[:parent_type]
    if @parent_type == 'network'
      ip_addresses = Network.find(params[:id]).ip_addresses
    elsif @parent_type == 'nic'
      ip_addresses = Nic.find(params[:id]).ip_addresses
    elsif @parent_type == 'bonding' and params[:id]
      ip_addresses = Bonding.find(params[:id]).ip_addresses
    else
      ip_addresses = []
    end

    ip_addresses_json = []
    ip_addresses.each{ |x|
          ip_addresses_json.push({:id => x.id, :name => x.address}) }
    render :json => ip_addresses_json
   end

   def new_ip_address
    @parent_type = params[:parent_type]
    @network = Network.find(params[:id]) if @parent_type == 'network'
    @nic = Nic.find(params[:id]) if @parent_type == 'nic'
    @bonding = Bonding.find(params[:id]) if @parent_type == 'bonding' and params[:id]

    render :layout => false
   end

  def _create_ip_address
    if params[:ip_address][:type] == "IpV4Address"
      @ip_address = IpV4Address.new(params[:ip_address])
    else
      @ip_address = IpV6Address.new(params[:ip_address])
    end
    @ip_address.save!
  end

  def create_ip_address
   begin
    _create_ip_address
    alert = "Ip Address was successfully created."
    render :json => { :object => "ip_address", :success => true,
                      :alert => alert  }
   rescue
    render :json => { :object => "ip_address", :success => false,
                      :errors =>
                        @ip_address.errors.localize_error_messages.to_a }
    end
   end

   def edit_ip_address
    @ip_address = IpAddress.find(params[:id])

    @parent_type = params[:parent_type]
    @network = @ip_address.network if @ip_address.network_id
    @nic = @ip_address.nic if @ip_address.nic_id
    @bonding = @ip_address.bonding if @ip_address.bonding_id

    render :layout => false
   end

   def _update_ip_address(id)
     @ip_address = IpAddress.find(id)

     # special case if we are switching types
     if @ip_address.type != params[:ip_address][:type]
       if params[:ip_address][:type] == 'IpV4Address'
          @ip_address = IpV4Address.new(params[:ip_address])
          @ip_address.save!
          IpV6Address.delete(id)
       else
          @ip_address = IpV6Address.new(params[:ip_address])
          @ip_address.save!
          IpV4Address.delete(id)
       end
     else
       if @ip_address.type == 'IpV4Address'
          @ip_address = IpV4Address.find(id)
       else
          @ip_address = IpV6Address.find(id)
       end
       @ip_address.update_attributes!(params[:ip_address])
     end

   end

   def update_ip_address
    begin
     _update_ip_address(params[:id])
     alert = "IpAddress was successfully updated."
     render :json => { :object => "network", :success => true,
                       :alert => alert  }
    rescue
     render :json => { :object => "ip_address", :success => false,
                        :errors =>
                        @ip_address.errors.localize_error_messages.to_a }
    end
   end

   def destroy_ip_address
    begin
     IpAddress.delete(params[:id])
     alert = "Ip Address was successfully deleted."
     render :json => { :object => "ip_address", :success => true,
                       :alert => alert  }
    rescue
     render :json => { :object => "ip_address", :success => false,
                      :alert => 'Ip Address Deletion Failed' }
     end
   end


   ########################## NICs related actions

   def edit_nic
     @nic = Nic.find(params[:id])
     @network = @nic.physical_network

     # filter out networks already assigned to nics on host
     network_conditions = []
     @nic.host.nics.each { |nic|
        unless nic.physical_network.nil? || nic.id == @nic.id
          network_conditions.push(" id != " + nic.physical_network.id.to_s)
        end
     }
     network_conditions = network_conditions.join(" AND ")

     @networks = PhysicalNetwork.find(:all, :conditions => network_conditions)
     network_options

     render :layout => false
   end

   def update_nic
    begin
     network_options

     unless params[:nic][:physical_network_id].nil? || params[:nic][:physical_network_id].to_i == 0
      @network = Network.find(params[:nic][:physical_network_id])
      if @network.boot_type.id == @static_boot_type.id
        if params[:ip_address][:id] == "New"
          _create_ip_address
        elsif params[:ip_address][:id] != ""
          _update_ip_address(params[:ip_address][:id])
        end
      end
     end

     @nic = Nic.find(params[:id])
     @nic.update_attributes!(params[:nic])

     alert = "Nic was successfully updated."
     render :json => { :object => "nic", :success => true,
                       :alert => alert  }
    rescue Exception => e
     if @ip_address and @ip_address.errors.size != 0
        render :json => { :object => "ip_address", :success => false,
                          :errors =>
                            @ip_address.errors.localize_error_messages.to_a}
     else
        render :json => { :object => "nic", :success => false,
                          :errors =>
                          @nic.errors.localize_error_messages.to_a }
     end
    end
   end

   ########################## Bonding related actions

   def new_bonding
    unless params[:host_id]
      flash[:notice] = "Host is required."
      redirect_to :controller => 'dashboard'
    end

    @host = Host.find(params[:host_id])

    # FIXME when bonding_nics table is removed, and
    # bondings_id column added to nics table, simplify
    # (select where bonding.nil?)
    @nics = []
    @host.nics.each{ |nic|
      @nics.push(nic) if nic.bondings.nil? || nic.bondings.size == 0
    }

    # filter out networks already assigned to bondings on host
    network_conditions = []
    @host.bondings.each { |bonding|
       unless bonding.vlan.nil?
         network_conditions.push(" id != " + bonding.vlan.id.to_s)
       end
    }
    network_conditions = network_conditions.join(" AND ")

    @networks = Vlan.find(:all, :conditions => network_conditions)
    network_options

    render :layout => false
   end

   def create_bonding
    begin
     network_options

     unless params[:bonding][:vlan_id].nil? || params[:bonding][:vlan_id].to_i == 0
       @network = Network.find(params[:bonding][:vlan_id])
       if @network.boot_type.id == @static_boot_type.id
         if params[:ip_address][:id] == "New"
           _create_ip_address
         elsif params[:ip_address][:id] != ""
           _update_ip_address(params[:ip_address][:id])
         end
       end
     end

    @bonding = Bonding.new(params[:bonding])
    @bonding.ip_addresses << @ip_address if @ip_address
    @bonding.save!

    if @ip_address
       @ip_address.bonding_id = @bonding.id
       @ip_address.save!
    end

     alert = "Bonding was successfully created."
     render :json => { :object => "bonding", :success => true,
                       :alert => alert  }
    rescue
     if @ip_address and @ip_address.errors.size != 0
        render :json => { :object => "ip_address", :success => false,
                          :errors =>
                            @ip_address.errors.localize_error_messages.to_a}
     else
        render :json => { :object => "bonding", :success => false,
                          :errors =>
                          @bonding.errors.localize_error_messages.to_a }
     end
    end
   end

   def edit_bonding
     @bonding = Bonding.find(params[:id])
     @network = @bonding.vlan

     @host = @bonding.host

     # FIXME when bonding_nics table is removed, and
     # bondings_id column added to nics table, simplify
     # (select where bonding.nil? or bonding has nic)
     @nics = []
     @host.nics.each{ |nic|
       if nic.bondings.nil? ||
          nic.bondings.size == 0 ||
          nic.bondings[0].id == @bonding.id
        @nics.push(nic)
       end
     }

     # filter out networks already assigned to bondings on host
     network_conditions = []
     @host.bondings.each { |bonding|
        unless bonding.vlan.nil? || bonding.id == @bonding.id
          network_conditions.push(" id != " + bonding.vlan.id.to_s)
        end
     }
     network_conditions = network_conditions.join(" AND ")

     @networks = Vlan.find(:all, :conditions => network_conditions)
     network_options

     render :layout => false
   end

   def update_bonding
    begin
     network_options

     unless params[:bonding][:vlan_id].nil? || params[:bonding][:vlan_id].to_i == 0
       @network = Network.find(params[:bonding][:vlan_id])
       if @network.boot_type.id == @static_boot_type.id
         if params[:ip_address][:id] == "New"
           _create_ip_address
         elsif params[:ip_address][:id] != ""
           _update_ip_address(params[:ip_address][:id])
         end
       end
     end

     @bonding = Bonding.find(params[:id])
     @bonding.nics.delete_all
     @bonding.update_attributes!(params[:bonding])

     alert = "Bonding was successfully updated."
     render :json => { :object => "bonding", :success => true,
                       :alert => alert  }
    rescue Exception => e
     if @ip_address and @ip_address.errors.size != 0
        render :json => { :object => "ip_address", :success => false,
                          :errors =>
                            @ip_address.errors.localize_error_messages.to_a}
     else
       render :json => { :object => "bonding", :success => false,
                          :errors =>
                          @bonding.errors.localize_error_messages.to_a }
     end
    end
   end

   def destroy_bonding
    begin
     Bonding.destroy(params[:id])
     alert = "Bonding was successfully deleted."
     render :json => { :object => "bonding", :success => true,
                       :alert => alert  }
    rescue
     render :json => { :object => "bonding", :success => false,
                      :alert => 'Bonding Deletion Failed' }
     end

   end


   ########################## Misc methods

  protected
   def network_options
    @bonding_types = BondingType.find(:all)
    @static_boot_type = BootType.find(:first,
                                 :conditions => { :proto => 'static' })
   end

end
