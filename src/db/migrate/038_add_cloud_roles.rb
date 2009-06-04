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

class AddCloudRoles < ActiveRecord::Migration
  def self.up
    Role.transaction do
      role_cloud_user = Role.new({:name => "Cloud User"})
      role_cloud_user.save!

      priv_cloud_create = Privilege.new({:name => "cloud_create"})
      priv_cloud_create.save!
      priv_cloud_view = Privilege.new({:name => "cloud_view"})
      priv_cloud_view.save!
      priv_vm_control = Privilege.find_by_name("vm_control")

      role_cloud_user.privileges = [priv_cloud_view,
                                    priv_vm_control,
                                    priv_cloud_create]
      role_cloud_user.save!
    end
  end

  def self.down
    Role.transaction do
      Role.find_by_name("Cloud User").destroy
      Privilege.find_by_name("cloud_create").destroy
      Privilege.find_by_name("cloud_view").destroy
    end
  end
end
