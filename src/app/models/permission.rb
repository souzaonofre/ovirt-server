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

class Permission < ActiveRecord::Base
  belongs_to :pool
  belongs_to :parent_permission, :class_name => "Permission",
             :foreign_key => "inherited_from_id"
  has_many   :child_permissions, :dependent => :destroy,
             :class_name => "Permission", :foreign_key => "inherited_from_id"

  belongs_to :role

  validates_presence_of :pool_id
  validates_presence_of :role_id

  validates_presence_of :uid
  validates_uniqueness_of :uid, :scope => [:pool_id, :inherited_from_id]

  def name
    @account ||= Account.find("uid=#{uid}")

    @account.cn
  end

  def is_primary?
    inherited_from_id.nil?
  end
  def is_inherited?
    !is_primary?
  end
  def source
    is_primary? ? "(Direct)" : parent_permission.pool.name
  end
  def grid_id
    id.to_s + "_" + (is_primary? ? "1" : "0")
  end
  # only update role for primary permissions, return false (and do nothing)
  # for inherited permissions
  def update_role(new_role)
    return false unless is_primary?
    self.transaction do
      self.role_id = new_role
      self.save!
      child_permissions.each do |permission|
        permission.role_id = new_role
        permission.save!
      end
    end
    true
  end
  def save_with_new_children
    self.transaction do
      self.save!
      pool.all_children.each do |subpool|
          new_permission = Permission.new({:pool_id     => subpool.id,
                                           :uid         => uid,
                                           :role_id     => role_id,
                                           :inherited_from_id => id})
          new_permission.save!
      end
    end
  end
end
