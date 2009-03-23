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
require 'test_helper'

class HelpSectionTest < ActiveSupport::TestCase
   fixtures :help_sections

   def setup
     @help_section = HelpSection.new(
         :controller => 'foo',
         :action => 'bar',
         :section => 'foobar')
   end

   def test_unique_controller_action
      @help_section.controller = 'dashboard'
      @help_section.action = 'index'

     flunk 'help section must have unique controller / action' if @help_section.valid?
   end

   def test_valid_fails_without_controller
     @help_section.controller = ''
     flunk 'help section controller must be specified' if @help_section.valid?
   end

   def test_valid_fails_without_action
     @help_section.action = ''
     flunk 'help section action must be specified' if @help_section.valid?
   end

   def test_valid_fails_without_section
     @help_section.section = ''
     flunk 'help section section must be specified' if @help_section.valid?
   end
end
