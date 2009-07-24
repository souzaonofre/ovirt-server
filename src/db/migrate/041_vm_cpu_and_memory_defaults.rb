# Copyright (C) 2009 Red Hat, Inc.
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

class VmCpuAndMemoryDefaults < ActiveRecord::Migration
  def self.up
    change_column :vms, :num_vcpus_allocated, :integer, :default => 1
    change_column :vms, :memory_allocated, :integer, :default => 262144 #256MB
  end

  def self.down
    change_column :vms, :num_vcpus_allocated, :integer, :default => nil
    change_column :vms, :memory_allocated, :integer, :default => nil
  end
end
