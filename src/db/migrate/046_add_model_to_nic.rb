# Copyright (C) 2010 Alcatel-Lucent
# Written by Nicolas Ochem <nicolas.ochem@alcatel-lucent.com>
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
class AddModelToNic < ActiveRecord::Migration
  def self.up
    add_column :nics, :model, :string
    remove_column :nics, :virtio
  end

  def self.down
    remove_column :nics, :model
    add_column :nics, :virtio, :boolean, :default => false
  end
end

