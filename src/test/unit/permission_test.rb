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

require File.dirname(__FILE__) + '/../test_helper'

class PermissionTest < Test::Unit::TestCase
  fixtures :permissions
  fixtures :pools

  def setup
    @permission = Permission.new(
        :uid => 'foobar',
        :user_role => 'Super Admin' )
    @permission.pool = pools(:root_dir_pool)
  end

  # Replace this with your real tests.
  def test_simple_permission
    assert_equal permissions(:ovirtadmin_root).user_role, 'Super Admin'
    assert_equal permissions(:ovirtadmin_root).pool.name, 'root'
  end

  def test_permission_with_parent
    assert_equal permissions(:ovirtadmin_default).inherited_from_id, permissions(:ovirtadmin_root).id
    assert_equal permissions(:ovirtadmin_default).parent_permission, permissions(:ovirtadmin_root)
  end

  def test_valid_fails_without_pool
    @permission.pool = nil
    flunk 'Permission must specify pool' if @permission.valid?
  end

  def test_valid_fails_without_uid
    @permission.uid = ''
    flunk 'Permission must specify uid' if @permission.valid?
  end

  def test_valid_fails_without_user_role
    @permission.user_role = ''
    flunk 'Permission must specify user role' if @permission.valid?
  end

  def test_valid_fails_with_invalid_user_role
    @permission.user_role = 'foobar'
    flunk 'Permission must specify valid user role' if @permission.valid?
  end
end
