#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>
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

class CreateBondings < ActiveRecord::Migration
  def self.up
    create_table :bondings do |t|
      t.string  :name,            :null => false, :limit => 50
      t.string  :interface_name,  :null => false, :limit => 20
      t.integer :bonding_type_id, :null => false
      t.foreign_key :bonding_types, :name => 'fk_bonding_bonding_type'
      t.integer :host_id,         :null => false
      t.foreign_key :hosts, :name => 'fk_bonding_host'
      t.string  :ip_addr,         :null => true, :limit => 15
      t.string  :netmask,         :null => true, :limit => 15
      t.string  :broadcast,       :null => true, :limit => 15
      t.string  :arp_ping_address,:null => true
      t.integer :arp_interval,    :null => false, :default => 0

      t.timestamps
    end

    add_index :bondings, [:interface_name, :host_id], :unique => true
  end

  def self.down
    drop_table :bondings
  end
end
