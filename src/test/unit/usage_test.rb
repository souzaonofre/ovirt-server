# Copyright (C) 2008 Red Hat, Inc.
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

require 'test_helper'

class UsageTest < ActiveSupport::TestCase
  fixtures :usages

   def setup
       @usage = Usage.new(
            :label => 'TestUsage',
            :usage => 'foobar' )
   end

   def test_valid_fails_without_label
      @usage.label = ''

      flunk 'Usage must have label' if @usage.valid?
   end

   def test_valid_fails_without_usage
      @usage.usage = ''

      flunk 'Usage must have usage' if @usage.valid?
   end

   def test_valid_fails_without_unique_usage
     @usage.usage = 'management'

      flunk 'Usage must have unique usage' if @usage.valid?
   end

end
