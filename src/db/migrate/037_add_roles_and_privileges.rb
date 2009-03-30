#
# Copyright (C) 2009 Red Hat, Inc.
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

class AddRolesAndPrivileges < ActiveRecord::Migration
  def self.up
    create_table :roles do |t|
      t.string  :name
      t.integer :lock_version, :default => 0
    end
    create_table :privileges do |t|
      t.string  :name
      t.integer :lock_version, :default => 0
    end

    create_table :privileges_roles, :id => false do |t|
      t.integer :privilege_id,             :null => false
      t.integer :role_id, :null => false
    end
    execute "alter table privileges_roles add constraint
             fk_priv_roles_role_id
             foreign key (role_id) references roles(id)"
    execute "alter table privileges_roles add constraint
             fk_priv_roles_priv_id
             foreign key (privilege_id) references privileges(id)"

    add_column :permissions, :role_id, :integer
    execute "alter table permissions add constraint fk_perm_roles
             foreign key (role_id) references roles(id)"

    #create default roles and privileges
    Role.transaction do
      role_super_admin = Role.new({:name => "Super Admin"})
      role_super_admin.save!
      role_admin = Role.new({:name => "Administrator"})
      role_admin.save!
      role_user = Role.new({:name => "User"})
      role_user.save!
      role_monitor = Role.new({:name => "Monitor"})
      role_monitor.save!

      priv_perm_set = Privilege.new({:name => "set_perms"})
      priv_perm_set.save!
      priv_perm_view = Privilege.new({:name => "view_perms"})
      priv_perm_view.save!
      priv_modify = Privilege.new({:name => "modify"})
      priv_modify.save!
      priv_vm_control = Privilege.new({:name => "vm_control"})
      priv_vm_control.save!
      priv_view = Privilege.new({:name => "view"})
      priv_view.save!

      role_super_admin.privileges = [priv_view, priv_vm_control, priv_modify,
                                     priv_perm_view, priv_perm_set]
      role_super_admin.save!
      role_admin.privileges       = [priv_view, priv_vm_control, priv_modify]
      role_admin.save!
      role_user.privileges        = [priv_view, priv_vm_control]
      role_user.save!
      role_monitor.privileges     = [priv_view]
      role_monitor.save!
      Permission.find(:all).each do |permission|
        permission.role = case permission.user_role
                          when "Super Admin"; role_super_admin
                          when "Administrator"; role_admin
                          when "User"; role_user
                          when "Monitor"; role_monitor
                          else nil
                          end
        permission.save
      end
    end
    remove_column :permissions, :user_role

  end


  def self.down
    add_column :permissions, :user_role, :string
    Permission.transaction do
      Permission.find(:all).each do |permission|
        case permission.role.name
        when ["Super Admin", "Administrator", "User", "Monitor"]
          permission.user_role = permission.role.name
          permission.save
        else
          permission.destroy
        end
      end
    end
    remove_column :permissions, :role_id

    drop_table :privileges_roles
    drop_table :privileges
    drop_table :roles
  end
end
