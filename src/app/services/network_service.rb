#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>,
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
# Mid-level API: Business logic around networks
module NetworkService
  include ApplicationService

  # Loads a list of networks for viewing
  #
  # === Instance variables
  # [<tt>@networks</tt>] stores a list of all Networks
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_list()
    authorize
    @networks = Network.find(:all)
  end

  # Load the Network with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@network</tt>] stores the Network with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_show(id)
    authorize(id)
  end

  # Load the Network with +id+ for editing
  #
  # === Instance variables
  # [<tt>@network</tt>] stores the Network with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on default HW pool
  def svc_modify(id)
    authorize(id)
  end

  # update attributes for the Network with +id+
  #
  # === Instance variables
  # [<tt>@network</tt>] stores the Network with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on default HW pool
  def svc_update(id, network_hash)
    authorize(id)
    @network.usages.delete_all
    @network.update_attributes!(network_hash)
    return "Network was successfully updated."
  end

  # Load a new Network for creating
  #
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on default HW pool
  def svc_new()
    authorize
  end

  # Save a new Network
  #
  # === Instance variables
  # [<tt>@network</tt>] the newly-created Network
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on default HW pool
  def svc_create(network_hash)
    authorize
    @network = Network.factory(network_hash)
    @network.save!
    return "Network was successfully created."
  end

  # Destroys the Network with +id+
  #
  # === Instance variables
  # [<tt>@network</tt>] stores the network with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on default HW pool
  def svc_destroy(id)
    authorize(id)
    unless @network.is_destroyable?
      raise ActionError.new("Network has existing bondings or NICs")
    end
    @network.destroy
    return "Network was successfully deleted."
  end

  # Load the IP addresses for object of type +parent_type+ and +id+
  #
  # === Instance variables
  # [<tt>@parent_type</tt>] +parent_type+
  # [<tt>@ip_addresses</tt>] IP addresses for selected object
  # [<tt>@network</tt>] network with +id+ if <tt>@parent_type</tt> is "network"
  # [<tt>@nic</tt>] nic with +id+ if <tt>@parent_type</tt> is "nic"
  # [<tt>@bonding</tt>] bonding with +id+ if <tt>@parent_type</tt> is "bonding"
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_ip_addresses(parent_type, id)
    authorize
    @parent_type = parent_type
    if @parent_type == 'network'
      @network = Network.find(id)
      @ip_addresses = @network.ip_addresses
    elsif @parent_type == 'nic'
      @nic = Nic.find(id)
      @ip_addresses = @nic.ip_addresses
    elsif @parent_type == 'bonding' and id
      @bonding = Bonding.find(id)
      @ip_addresses = @bonding.ip_addresses
    else
      @ip_addresses = []
    end
  end

  # create new IP address
  #
  # === Instance variables
  # [<tt>@ip_address</tt>] create new IP address
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_create_ip_address(ip_hash)
    authorize
    @ip_address = IpAddress.factory(ip_hash)
    @ip_address.save!
    return "Ip Address was successfully created."
  end

  # Load IP address +id+ for editing
  #
  # === Instance variables
  # [<tt>@ip_address</tt>] IP Address with +id+
  # [<tt>@network</tt>] network for <tt>@ip_address</tt> if it exists
  # [<tt>@nic</tt>] nic for <tt>@ip_address</tt> if it exists
  # [<tt>@bonding</tt>] bonding for <tt>@ip_address</tt> if it exists
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_modify_ip_address(parent_type, id)
    authorize
    @ip_address = IpAddress.find(id)
    @parent_type = parent_type
    @network = @ip_address.network if @ip_address.network_id
    @nic = @ip_address.nic if @ip_address.nic_id
    @bonding = @ip_address.bonding if @ip_address.bonding_id
  end

  # Update IP address +id+
  #
  # === Instance variables
  # [<tt>@ip_address</tt>] IP Address with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_update_ip_address(id, ip_hash)
    authorize
    @ip_address = IpAddress.find(id)
    # special case if we are switching types
    # FIXME: this doesn't work if all attributes aren't specified
    # We should probably not support changing type here but instead require
    # deletion and re-creation -- either that or don't use inheritence for
    # IP address type
    if @ip_address.type != ip_hash[:type]
      @ip_address = IpAddress.factory(ip_hash)
      @ip_address.save!
      IpAddress.delete(id)
    else
      @ip_address.update_attributes!(ip_hash)
    end
    return "IpAddress was successfully updated."
  end

  # Destroys the IP Address with +id+
  #
  # === Instance variables
  # [<tt>@ip_address</tt>] stores the IP Address with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on default HW pool
  def svc_destroy_ip_address(id)
    authorize
    IpAddress.destroy(id)
    return "IP Address was successfully deleted."
  end

  # Load NIC +id+ for editing
  #
  # === Instance variables
  # [<tt>@nic</tt>] NIC with +id+
  # [<tt>@network</tt>] network for <tt>@nic</tt>
  # [<tt>@networks</tt>] available networks for <tt>@nic</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_modify_nic(id)
    authorize
    @nic = Nic.find(id)
    @network = @nic.physical_network
    network_options
    # filter out networks already assigned to nics on host
    network_conditions = []
    @nic.host.nics.each { |nic|
      unless nic.physical_network.nil? || nic.id == @nic.id
        network_conditions.push(" id != " + nic.physical_network.id.to_s)
      end
    }
    network_conditions = network_conditions.join(" AND ")
    @networks = PhysicalNetwork.find(:all, :conditions => network_conditions)
  end

  # Update NIC +id+
  #
  # === Instance variables
  # [<tt>@nic</tt>] NIC with +id+
  # [<tt>@network</tt>] network for <tt>@nic</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_update_nic(id, nic_hash, ip_hash)
    authorize
    network_options
    unless nic_hash[:physical_network_id].to_i == 0
      @network = Network.find(nic_hash[:physical_network_id])
      if @network.boot_type.id == @static_boot_type.id
        if ip_hash[:id] == "New"
          svc_create_ip_address(ip_hash)
        elsif ip_hash[:id] != ""
          svc_update_ip_address(ip_hash[:id], ip_hash)
        end
      end
    end
    @nic = Nic.find(id)
    @nic.update_attributes!(nic_hash)
    return "Nic was successfully updated."
  end

  # load new bonding for creation
  #
  # === Instance variables
  # [<tt>@host</tt>] Host with +host_id+
  # [<tt>@nics</tt>] available nics on <tt>@host</tt>
  # [<tt>@networks</tt>] available networks
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_new_bonding(host_id)
    authorize
    network_options
    @host = Host.find(host_id)
    # FIXME when bonding_nics table is removed, and
    # bondings_id column added to nics table, simplify
    # (select where bonding.nil?)
    @nics = []
    @host.nics.each{ |nic| @nics.push(nic) if nic.bondings.empty? }
    # filter out networks already assigned to bondings on host
    network_conditions = []
    @host.bondings.each { |bonding|
       unless bonding.vlan.nil?
         network_conditions.push(" id != " + bonding.vlan.id.to_s)
       end
    }
    network_conditions = network_conditions.join(" AND ")
    @networks = Vlan.find(:all, :conditions => network_conditions)
  end

  # create new bonding
  #
  # === Instance variables
  # [<tt>@bonding</tt>] newly created bonding
  # [<tt>@network</tt>] network for newly created bonding (if vlan specified)
  # [<tt>@ip_address</tt>] ip address for newly created bonding (if vlan
  #                        and static boot type specified)
  # [<tt>@host</tt>] Host with +host_id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_create_bonding(bonding_hash, ip_hash)
    pre_create_or_update_bonding(bonding_hash, ip_hash)
    @bonding = Bonding.new(bonding_hash)
    @bonding.ip_addresses << @ip_address if @ip_address
    @bonding.save!
    if @ip_address
      @ip_address.bonding_id = @bonding.id
      @ip_address.save!
    end
    return "Bonding was successfully created."
  end

  # Load Bonding +id+ for editing
  #
  # === Instance variables
  # [<tt>@bonding</tt>] bonding with +id+
  # [<tt>@host</tt>] host for <tt>@bonding</tt>
  # [<tt>@network</tt>] network for <tt>@bonding</tt>
  # [<tt>@networks</tt>] available networks
  # [<tt>@nics</tt>] available nics
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_modify_bonding(id)
    authorize
    @bonding = Bonding.find(id)
    @network = @bonding.vlan
    @host = @bonding.host

    # FIXME when bonding_nics table is removed, and
    # bondings_id column added to nics table, simplify
    # (select where bonding.nil? or bonding has nic)
    @nics = []
    @host.nics.each{ |nic|
      if nic.bondings.empty? ||
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
  end

  # Update Bonding +id+
  #
  # === Instance variables
  # [<tt>@bonding</tt>] bonding with +id+
  # [<tt>@network</tt>] network for <tt>@bonding</tt>
  # [<tt>@ip_address</tt>] ip address for newly created bonding (if vlan
  #                        and static boot type specified)
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on the default HW pool
  def svc_update_bonding(id, bonding_hash, ip_hash)
    pre_create_or_update_bonding(bonding_hash, ip_hash)
    @bonding = Bonding.find(id)
    @bonding.nics.delete_all
    @bonding.update_attributes!(bonding_hash)
    return "Bonding was successfully updated."
  end

  # Destroys the Bonding with +id+
  #
  # === Instance variables
  # [<tt>@bonding</tt>] stores the Bonding with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on default HW pool
  def svc_destroy_bonding(id)
    authorize
    Bonding.destroy(id)
    return "Bonding was successfully deleted."
  end

  private
  # for now we only check for deafult pool admin auth
  def authorize(id=nil)
    authorized!(Privilege::MODIFY,HardwarePool.get_default_pool)
    @network = Network.find(id) if id
  end
  def network_options
    @bonding_types = BondingType.find(:all)
    @static_boot_type = BootType.find(:first,
                                      :conditions => { :proto => 'static' })
  end
  def pre_create_or_update_bonding(bonding_hash, ip_hash)
    authorize
    network_options
    unless bonding_hash[:vlan_id].to_i == 0
      @network = Network.find(bonding_hash[:vlan_id])
      if @network.boot_type.id == @static_boot_type.id
        if ip_hash[:id] == "New"
          svc_create_ip_address(ip_hash)
        elsif ip_hash[:id] != ""
          svc_update_ip_address(ip_hash[:id], ip_hash)
        end
      end
    end
  end
end
