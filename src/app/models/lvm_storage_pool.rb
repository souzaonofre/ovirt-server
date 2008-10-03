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

require 'util/ovirt'

class LvmStoragePool < StoragePool

  has_many :source_volumes, :class_name => "StorageVolume",
                            :foreign_key => "lvm_pool_id",
                            :dependent => :nullify do
    def total_size
      find(:all).inject(0){ |sum, sv| sum + sv.size }
    end
  end

  validates_presence_of :vg_name
  validates_uniqueness_of :vg_name

  def display_name
    "#{get_type_label}: #{vg_name}"
  end

  def size
    source_volums.total_size
  end

  def size_in_gb
    kb_to_gb(size)
  end


end
