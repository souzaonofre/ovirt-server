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

class AddSmartPools < ActiveRecord::Migration
  def self.up
    create_table :smart_pool_tags  do |t|
      t.integer :smart_pool_id, :null => false
      t.integer :tagged_id,     :null => false
      t.string :tagged_type,    :null => false
    end
    execute "alter table smart_pool_tags add constraint
             fk_smart_pool_tags_pool_id
             foreign key (smart_pool_id) references pools(id)"
    execute "alter table smart_pool_tags add constraint
             unique_smart_pool_tags
             unique (smart_pool_id, tagged_id, tagged_type)"

    begin
      dir_root = DirectoryPool.get_directory_root
      unless dir_root
        Pool.transaction do
          dir_root = DirectoryPool.create(:name=>DirectoryPool::ROOT_NAME)
          hw_root = DirectoryPool.new(:name=>DirectoryPool::HARDWARE_ROOT)
          hw_root.create_with_parent(dir_root)
          smart_root = DirectoryPool.new(:name=>DirectoryPool::SMART_ROOT)
          smart_root.create_with_parent(dir_root)
          default_pool = Pool.root(:conditions=>"type='HardwarePool'")
          default_pool = HardwarePool.create( :name=>'default') unless default_pool
          default_pool.move_to_child_of(hw_root)
          default_pool.permissions.each do |permission|
            new_permission = Permission.new({:pool_id     => dir_root.id,
                                             :uid         => permission.uid,
                                             :user_role   => permission.user_role})
            new_permission.save_with_new_children
          end
        end
      end
    rescue
      puts "Could not create DirectoryPool hierarchy..."
    end
  end

  def self.down
    drop_table :smart_pool_tags
  end
end
