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

class QuotaTest < Test::Unit::TestCase
  fixtures :quotas
  fixtures :pools

  def setup
    @quota = Quota.new
    @quota.pool = pools(:root_dir_pool)
  end

  def test_valid_fails_without_pool
    @quota.pool = nil
    flunk "Quota's must specify pool" if @quota.valid?
  end

  def test_valid_fails_with_bad_total_vcpus
    @quota.total_vcpus = -1
    flunk "Quota must specify valid total vcpus" if @quota.valid?
  end

  def test_valid_fails_with_bad_total_vmemory
    @quota.total_vmemory = -1
    flunk "Quota must specify valid total vmemory" if @quota.valid?
  end

  def test_valid_fails_with_bad_total_vnics
    @quota.total_vnics = -1
    flunk "Quota must specify valid total vnics" if @quota.valid?
  end

  def test_valid_fails_with_bad_total_storage
    @quota.total_storage = -1
    flunk "Quota must specify valid total storage" if @quota.valid?
  end

  def test_valid_fails_with_bad_total_vms
    @quota.total_vms = -1
    flunk "Quota must specify valid total vms" if @quota.valid?
  end
end
