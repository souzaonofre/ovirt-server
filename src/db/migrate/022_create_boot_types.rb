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

class CreateBootTypes < ActiveRecord::Migration
  def self.up
    create_table :boot_types do |t|
      t.string :label, :null => false, :limit => 25
      t.string :proto, :null => false, :limit => 25

      t.timestamps
    end

    add_index :boot_types, :label, :unique => true
    add_index :boot_types, :proto, :unique => true

    BootType.create(:label => 'Static IP', :proto => 'static')
    BootType.create(:label => 'DHCP',      :proto => 'dhcp')
    BootType.create(:label => 'BOOTP',     :proto => 'bootp')

    add_column :nics, :boot_type_id, :integer, :null => true

    execute 'alter table nics add constraint fk_nic_boot_type
             foreign key (boot_type_id) references boot_types(id)'

    boot_type = BootType.find_by_proto('static')

    Nic.find(:all).each do |nic|
      nic.boot_type_id = boot_type.id
      nic.save!
    end

    change_column :nics, :boot_type_id, :integer, :null => false
  end

  def self.down
    remove_column :nics, :boot_type_id

    drop_table :boot_types
  end
end
