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

class DirectoryPool < Pool

  ROOT_NAME     = "root"
  HARDWARE_ROOT = "hardware"
  SMART_ROOT    = "users"

  def self.get_directory_root
    self.root(:conditions=>"type='DirectoryPool'")
  end

  def self.get_hardware_root
    dir_root = get_directory_root
    dir_root ? dir_root.named_child(HARDWARE_ROOT) : nil
  end

  def self.get_smart_root
    dir_root = get_directory_root
    dir_root ? dir_root.named_child(SMART_ROOT) : nil
  end

  def self.get_user_root(user)
    smart_root = get_smart_root
    smart_root ? smart_root.named_child(user) : nil
  end

  def self.get_or_create_user_root(user)
    user_root = get_user_root(user)
    unless user_root
      DirectoryPool.transaction do
        user_root = DirectoryPool.new(:name => user)
        user_root.create_with_parent(get_smart_root)
        permission = Permission.new({:pool_id => user_root.id,
                                     :uid => user,
                                     :user_role => Permission::ROLE_SUPER_ADMIN})
        #we don't need save_with_new_children here since there are no children yet
        permission.save!
      end
    end
  end

end
