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

# introduce networks and ip_addresses tables, refactor relationships
class RefactorNetworkingModel < ActiveRecord::Migration
  def self.up

    ####################################################
    # bugfix, bridge tables shouldn't have their own ids
    remove_column :bondings_nics, :id

    ##################################################################
    # add networks, usages tables and networks_usage_types bridge
    create_table :networks do |t|
      t.string  :type, :null => false
      t.string  :name, :null => false
      t.integer :boot_type_id, :null => false
      t.foreign_key :boot_types, :name => 'fk_network_boot_types'

      # attributes for Vlan (type=Vlan)
      t.integer :number
    end

    create_table :usages do |t|
      t.string :label, :null => false
      t.string :usage, :null => false
    end

    create_table :networks_usages, :id => false do |t|
      t.integer :network_id, :null => false
      t.foreign_key :networks, :name => 'fk_networks_usages_network_id'
      t.integer :usage_id, :null => false
      t.foreign_key :networks, :name => 'fk_networks_usages_usage_id'
    end

    add_index :networks_usages, [:network_id, :usage_id], :unique => true

    # create usages
    Usage.create(:label => 'Guest', :usage => 'guest')
    Usage.create(:label => 'Management', :usage => 'management')
    Usage.create(:label => 'Storage', :usage => 'storage')

    # add foreign keys to nics / bondings table
    add_column :nics, :physical_network_id, :integer
    add_foreign_key :nics, :networks, :column => 'physical_network_id',
                                      :name => 'fk_nic_networks'
    add_column :bondings, :vlan_id, :integer
    add_foreign_key :bondings, :networks, :column => 'vlan_id',
                                          :name => 'fk_bonding_networks'

    ####################################################
    # create ip_addresses table
    create_table :ip_addresses do |t|
      t.string :type

      # foreign keys to associated entities
      t.integer :nic_id
      t.foreign_key :nics, :name => 'fk_nic_ip_addresses'
      t.integer :bonding_id
      t.foreign_key :bondings, :name => 'fk_bonding_ip_addresses'
      t.integer :network_id
      t.foreign_key :networks, :name => 'fk_network_ip_addresses'

      # common attributes
      t.string :address,   :limit => 39, :null => false
      t.string :gateway,   :limit => 39

      # attributes for IPv4 (type=IpV4Address)
      t.string :netmask,   :limit => 15
      t.string :broadcast, :limit => 15

      # attributes for IPv6 (type=IpV6Address)
      t.string :prefix,    :limit => 39
      t.timestamps
    end

    ###################################################################
    static_boot_type_id =
      BootType.find(:first,
           :conditions => {:proto => 'static'} ).id

    # migrate nic ip_addresses to networks / ip_addresses table
    i = 0
    Nic.find(:all).each do |nic|
      if nic.boot_type_id == static_boot_type_id
        IpV4Address.new(:nic_id    => nic.id,
                        :address   => nic.ip_addr).save!

      end
      network = PhysicalNetwork.new(
                            :name => 'Physical Network ' + i.to_s,
                            :boot_type_id => nic.boot_type_id)
      network.save!

      ip_address = IpV4Address.new(:address   => nic.ip_addr ? nic.ip_addr : '0.0.0.0',
                                   :netmask   => nic.netmask,
                                   :broadcast => nic.broadcast,
                                   :gateway   => nic.ip_addr)
      ip_address.network = network
      ip_address.save!

      nic.physical_network = network
      nic.save!

      i += 1
    end

    # migrate bonding ip_addresses to networks / ip_addresses table
    i = 0
    Bonding.find(:all).each do |bonding|
      if bonding.boot_type_id == static_boot_type_id
        IpV4Address.new(:bonding_id => bonding.id,
                        :address    => bonding.ip_addr).save!
      end
      network = Vlan.new(
                     :name => 'VLAN ' + i.to_s,
                     :number => i,
                     :boot_type_id => bonding.boot_type_id)
      network.save!

      ip_address = IpV4Address.new(:address   => bonding.ip_addr ? bonding.ip_addr : '0.0.0.0',
                                   :netmask   => bonding.netmask,
                                   :broadcast => bonding.broadcast,
                                   :gateway   => bonding.ip_addr)
      ip_address.network = network
      ip_address.save!

      bonding.vlan = network
      bonding.save!

      i += 1
    end

    ##############################################################
    # remove nics / bonding ip address and network related columns
    remove_column :nics,     :ip_addr
    remove_column :nics,     :netmask
    remove_column :nics,     :broadcast
    remove_foreign_key :nics, :name => 'fk_nic_boot_type'
    remove_column :nics,     :boot_type_id
    remove_column :bondings, :ip_addr
    remove_column :bondings, :netmask
    remove_column :bondings, :broadcast
    remove_foreign_key :bondings, :name => 'fk_bondings_boot_type'
    remove_column :bondings, :boot_type_id


  end

  def self.down
    ##############################################################
    # readd nics / bonding ip address related columns
    add_column :nics,     :ip_addr,   :string, :limit => 16
    add_column :nics,     :netmask,   :string, :limit => 16
    add_column :nics,     :broadcast, :string, :limit => 16
    add_column :nics,     :boot_type_id, :integer
    add_column :bondings, :ip_addr,   :string, :limit => 16
    add_column :bondings, :netmask,   :string, :limit => 16
    add_column :bondings, :broadcast, :string, :limit => 16
    add_column :bondings, :boot_type_id, :integer

    add_foreign_key :nics, :boot_types, :name => 'fk_nic_boot_type'
    add_foreign_key :bondings, :boot_types, :name => 'fk_bondings_boot_type'

    ##############################################################
    # attempt to migrate ip information back into nics table.
    #  because a nic can have multiple ips (if statically
    #  assigned) as well as its network, just use the 1st
    #  found
    Nic.find(:all).each do |nic|
      if nic.physical_network.ip_addresses.size > 0
        # use the 1st configured network ip
        nic.ip_addr   = nic.physical_network.ip_addresses[0].address
        nic.netmask   = nic.physical_network.ip_addresses[0].netmask
        nic.broadcast = nic.physical_network.ip_addresses[0].broadcast
      end

      if nic.ip_addresses.size > 0
        # use the 1st assigned static ip
        nic.ip_addr   = nic.ip_addresses[0].address
      end

      nic.boot_type_id = nic.physical_network.boot_type_id

      nic.save!
    end

    # attempt to migrate ip information back into bondings table.
    #  because a bonding can have multiple ips (if statically
    #  assigned) as well as its network, just use the 1st
    #  found
    Bonding.find(:all).each do |bonding|
      if bonding.vlan.ip_addresses.size > 0
        # use the 1st configured network ip
        bonding.ip_addr   = bonding.vlan.ip_addresses[0].address
        bonding.netmask   = bonding.vlan.ip_addresses[0].netmask
        bonding.broadcast = bonding.vlan.ip_addresses[0].broadcast
      end

      if bonding.ip_addresses.size > 0
        # use the 1st assigned static ip
        bonding.ip_addr   = bonding.ip_addresses[0].address
      end

      bonding.boot_type_id = bonding.vlan.boot_type_id

      bonding.save!
    end

    ##############################################################
    # drop ip_addresses table
    drop_table :ip_addresses

    # drop network ids from nics / bondings table
    remove_column :nics, :physical_network_id
    remove_column :bondings, :vlan_id

    # drop networks tables
    drop_table :networks_usages
    drop_table :usages
    drop_table :networks

    ##############################################################
    # undo bugfix above
    add_column :bondings_nics, :id, :integer
  end
end
