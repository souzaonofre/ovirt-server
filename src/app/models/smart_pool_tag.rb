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

class SmartPoolTag < ActiveRecord::Base
  belongs_to :smart_pool
  belongs_to :tagged,       :polymorphic => true
  belongs_to :pool,         :class_name => "Pool",
                            :foreign_key => "tagged_id"
  belongs_to :storage_pool, :class_name => "StoragePool",
                            :foreign_key => "tagged_id"
  belongs_to :host,         :class_name => "Host",
                            :foreign_key => "tagged_id"
  belongs_to :vm,           :class_name => "Vm",
                            :foreign_key => "tagged_id"

  validates_uniqueness_of :smart_pool_id, :scope => [:tagged_id, :tagged_type]

  def tagged_type=(sType)
    super(sType.to_s.classify.constantize.base_class.to_s)
  end
end
