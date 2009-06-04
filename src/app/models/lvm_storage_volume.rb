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

class LvmStorageVolume < StorageVolume

  def initialize(params)
    super
    self.lv_owner_perms='0744' unless self.lv_owner_perms
    self.lv_group_perms='0744' unless self.lv_group_perms
    self.lv_mode_perms='0744' unless self.lv_mode_perms
  end

  def display_name
    "#{get_type_label}: #{storage_pool.vg_name}:#{lv_name}"
  end

  def volume_name
    "lv_name"
  end

  def volume_create_params
    return lv_name, size, lv_owner_perms, lv_group_perms, lv_mode_perms
  end

  validates_presence_of :lv_name
  validates_presence_of :lv_owner_perms
  validates_presence_of :lv_group_perms
  validates_presence_of :lv_mode_perms

  def ui_parent
    storage_pool.source_volumes[0][:type].to_s + '_' +storage_pool.source_volumes[0].id.to_s
  end
end
