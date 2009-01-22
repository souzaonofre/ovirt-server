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

class StorageVolumeTest < Test::Unit::TestCase
  fixtures :storage_volumes
  fixtures :storage_pools
  fixtures :vms

  def setup
     @storage_volume = StorageVolume.new(
           :size => 100,
           :type => 'IscsiStorageVolume',
           :state => 'available' )

     @iscsi_storage_volume = IscsiStorageVolume.new(
           :lun => 'foobar',
           :size => 100,
           :state => 'available' )

     @lvm_storage_volume = LvmStorageVolume.new(
           :lv_name => 'foobar',
           :lv_owner_perms => '0700',
           :lv_group_perms => '0777',
           :lv_mode_perms => '0000' )

     @storage_volume.storage_pool = storage_pools(:corp_com_ovirtpriv_storage)
     @iscsi_storage_volume.storage_pool = storage_pools(:corp_com_ovirtpriv_storage)
     @lvm_storage_volume.storage_pool = storage_pools(:corp_com_dev_lvm_ovirtlvm)
  end

  # Replace this with your real tests.
  def test_relationship_to_storage_pool
    assert_equal 'corp.com', storage_volumes(:ovirtpriv_storage_lun_1).storage_pool.hardware_pool.name
  end


  def test_valid_fails_with_bad_size
       @storage_volume.size = -1

       flunk "Storage volume size must be >= 0" if @storage_volume.valid?
  end

  def test_valid_fails_with_bad_type
       @storage_volume.type = 'foobar'

       flunk "Storage volume type must be valid" if @storage_volume.valid?
  end

  def test_valid_fails_with_bad_state
       @storage_volume.state = 'foobar'
       flunk "Storage volume state must be valid" if @storage_volume.valid?
  end

  def test_valid_fails_without_storage_pool
       @storage_volume.storage_pool = nil

       flunk "Storage volume must be associated with a storage pool" if @storage_volume.valid?
  end

  def test_valid_fails_without_lun
       @iscsi_storage_volume.lun = ''

       flunk "iscsi storage volume lun must be valid" if @iscsi_storage_volume.valid?
  end

  def test_valid_fails_without_lv_name
       @lvm_storage_volume.lv_name = ''

       flunk "lvm storage volume lv_name must be valid" if @lvm_storage_volume.valid?
  end

  def test_valid_fails_without_lv_owner_perms
       @lvm_storage_volume.lv_owner_perms = ''

       flunk "lvm storage volume lv_owner_perms must be valid" if @lvm_storage_volume.valid?
  end

  def test_valid_fails_without_lv_group_perms
       @lvm_storage_volume.lv_group_perms = ''

       flunk "lvm storage volume lv_group_perms must be valid" if @lvm_storage_volume.valid?
  end

  def test_valid_fails_without_lv_model_perms
       @lvm_storage_volume.lv_mode_perms = ''

       flunk "lvm storage volume lv_model_perms must be valid" if @lvm_storage_volume.valid?
  end

  def test_movable
    assert_equal @storage_volume.movable?, true, "Storage volume without vms should be movable"
    @storage_volume.vms << vms(:production_httpd_vm)

    assert_equal @storage_volume.movable?, false, "Storage volume w/ vms should not be movable"
  end

end
