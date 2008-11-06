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

class StorageStateField < ActiveRecord::Migration
  def self.up
    add_column :storage_pools, :state, :string
    add_column :storage_volumes, :state, :string
    begin
      StoragePool.transaction do
        StoragePool.find(:all).each do |pool|
          pool.state = 'available'
          pool.save!
        end
        StorageVolume.find(:all).each do |volume|
          volume.state = 'available'
          volume.save!
        end
      end
    end
  end

  def self.down
    remove_column :storage_pools, :state
    remove_column :storage_volumes, :state
  end
end
