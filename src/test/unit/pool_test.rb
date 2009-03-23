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

class PoolTest < Test::Unit::TestCase
  fixtures :pools

  def setup
     @pool = Pool.new(
       :name => 'foobar',
       :type => 'DirectoryPool' )
  end

  # Replace this with your real tests.
  def test_get_name
    assert_equal(pools(:corp_com_prod).name, 'Production Operations')
  end

  def test_get_parent
    assert_equal(pools(:corp_com_prod).parent.name, 'corp.com')
  end

  def test_valid_fails_without_name
     @pool.name = ''
     flunk "Pool must specify name" if @pool.valid?
  end

  def test_valid_fails_without_unique_name
     @pool.name = 'root'
     flunk "Pool must specify unique name" if @pool.valid?
  end

  def test_valid_fails_with_invalid_type
     @pool.name = 'foobar'
     flunk "Pool must specify valid type" if @pool.valid?
  end
end
