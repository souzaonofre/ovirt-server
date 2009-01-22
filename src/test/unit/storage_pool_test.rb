# 
# Copyright (C) 2008 Red Hat, Inc.
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

require File.dirname(__FILE__) + '/../test_helper'

class StoragePoolTest < Test::Unit::TestCase
  fixtures :storage_pools
  fixtures :pools
  fixtures :vms

  def setup
    @storage_pool = StoragePool.new(
         :type => 'IscsiStoragePool',
         :capacity => 100,
         :state => 'available' )
    @storage_pool.hardware_pool = pools(:default)
  end

  def test_valid_fails_without_hardware_pool
    @storage_pool.hardware_pool = nil
    flunk "Storage pool must specify hardware pool" if @storage_pool.valid?
  end

  def test_valid_fails_with_bad_type
    @storage_pool.type = 'foobar'
    flunk 'Storage pool must specify valid type' if @storage_pool.valid?
  end

  def test_valid_fails_with_bad_capacity
    @storage_pool.capacity = -1
    flunk 'Storage pool must specify valid capacity >= 0' if @storage_pool.valid?
  end

  def test_valid_fails_with_bad_state
    @storage_pool.state = 'foobar'
    flunk 'Storage pool must specify valid state' if @storage_pool.valid?
  end

  def test_hardware_pool_relationship
    assert_equal 'corp.com', storage_pools(:corp_com_ovirtpriv_storage).hardware_pool.name
  end

  def test_movable
    assert_equal @storage_pool.movable?, true, "Storage pool without volumes should be movable"

    storage_volume = StorageVolume.new(
           :size => 100,
           :type => 'IscsiStorageVolume',
           :state => 'available' )
    @storage_pool.storage_volumes << storage_volume

    assert_equal @storage_pool.movable?, true, "Storage pool w/ movable storage volumes should be movable"

    storage_volume.vms << vms(:production_httpd_vm)
    assert_equal @storage_pool.movable?, false, "Storage pool w/ unmovable storage volumes should not be movable"
  end
end
