# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>
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

class BootTypeTest < ActiveSupport::TestCase
  fixtures :boot_types

   def setup
       @boot_type = BootType.new(
            :label => 'TestBootType',
            :proto => 'static' )
   end

   def test_valid_fails_without_label
      @boot_type.label = ''

      flunk 'Boot type must have label' if @boot_type.valid?
   end

   def test_valid_fails_without_unique_label
     @boot_type.label = 'Static IP'

      flunk 'Boot type must have unique label' if @boot_type.valid?
   end

   def test_valid_fails_with_bad_proto
     @boot_type.proto = 'foobar'

      flunk 'Boot type must have valid proto' if @boot_type.valid?
   end

   def test_find_all_for_boot_type
      result = BootType.find(:all)

      assert_equal 3, result.size, "Did not find right number of boot types"
   end

end
