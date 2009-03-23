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
#
# +HelpSection+ defines a section of the web help document to be
# available for a specific controller / action
#
class HelpSection < ActiveRecord::Base

    validates_uniqueness_of :action,
        :scope => :controller,
        :message => 'Controller / Action must be unique'

    validates_presence_of :controller,
        :message => 'A controller must be specified.'

    validates_presence_of :action,
        :message => 'An action must be specified.'

    validates_presence_of :section,
        :message => 'A section must be specified.'
end
