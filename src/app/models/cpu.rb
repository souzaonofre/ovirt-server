#
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

# +Cpu+ represents the details for a single CPU on a managed node.
#
class Cpu < ActiveRecord::Base
    belongs_to :host

    validates_presence_of :host_id,
        :message => 'A host must be specified.'

    validates_numericality_of :cpu_number,
        :greater_than_or_equal_to => 0

    validates_numericality_of :core_number,
        :greater_than_or_equal_to => 0

    validates_numericality_of :number_of_cores,
        :greater_than_or_equal_to => 1

    validates_numericality_of :cpuid_level,
        :greater_than_or_equal_to => 0

    validates_numericality_of :speed,
        :greater_than => 0
    # also verify speed in MHz ?

    validates_presence_of :vendor
    validates_presence_of :model
    validates_presence_of :family
end
