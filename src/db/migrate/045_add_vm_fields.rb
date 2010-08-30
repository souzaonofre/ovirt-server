# Copyright (C) 2010 Linagora.
# Written by Michel Loiseleur <mloiseleur@linagora.com>
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

# introduce information fields for VMs
class AddVmFields < ActiveRecord::Migration
  def self.up
    add_column :vms, :contact, :string, :null => false, :default => ''
    add_column :vms, :comment, :string, :null => false, :default => ''
    add_column :vms, :eol, :date, :null => false, :default => Date.new(1970,01,01).to_s
    add_column :vms, :os, :string, :null => false, :default => ''
  end

  def self.down
    remove_column :vms, :contact
    remove_column :vms, :comment
    remove_column :vms, :eol
    remove_column :vms, :os
  end
end
