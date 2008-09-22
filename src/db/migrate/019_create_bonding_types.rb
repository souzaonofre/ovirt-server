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

class CreateBondingTypes < ActiveRecord::Migration
  def self.up
    create_table :bonding_types do |t|
      t.string  :label, :null => false, :limit => 20
      t.integer :mode,  :null => false
    end

    add_index :bonding_types, :label, :unique => true
    add_index :bonding_types, :mode,  :unique => true

    # The order of the records is not related to the mode value.
    # Instead, they are ordered this way to ensure they're presented
    # in this particular order when loaded.
    #
    BondingType.create :label => 'Load Balancing',   :mode => 2
    BondingType.create :label => 'Failover',         :mode => 1
    BondingType.create :label => 'Broadcast',        :mode => 3
    BondingType.create :label => 'Link Aggregation', :mode => 4
  end

  def self.down
    drop_table :bonding_types
  end
end
