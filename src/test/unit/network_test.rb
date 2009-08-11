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

class NetworkTest < ActiveSupport::TestCase
 fixtures :networks
 fixtures :vms
 fixtures :hosts
 fixtures :nics
 fixtures :boot_types

 def setup
 end

 def test_vlan_invalid_without_number
   vl = Vlan.new({:name => 'testvlan', :boot_type_id => 2})
   flunk "Vlan without number should not be valid" if vl.valid?
   vl.number = 1
   flunk "Vlan with number should be valid" unless vl.valid?
 end

 def test_vlan_nics_only_associated_with_vm
   vl = Vlan.create({:name => 'testvlan',
                     :boot_type => boot_types(:boot_type_dhcp),
                     :number => 1}) # need to create for id
   nic = Nic.new({:mac => '11:22:33:44:55:66',
                  :bandwidth => 100,
                  :network => vl,
                  :host => hosts(:prod_corp_com)})
   vl.nics.push nic
   flunk "Nic assigned to vlan must only be associated with vm" if vl.valid?
   nic.host = nil
   nic.vm = vms(:production_httpd_vm)
   flunk "Vlan consisting of only vm nics should be valid" unless vl.valid?
 end

 def test_physical_network_is_destroyable
   pn = PhysicalNetwork.new
   flunk "PhysicalNetwork with no nics should be destroyable" unless pn.is_destroyable?
   pn.nics.push Nic.new
   flunk "PhysicalNetwork with nics should not be destroyable" if pn.is_destroyable?
 end

 def test_vlan_is_destroyable
   vl = Vlan.new
   flunk "Vlan with no nics and bondings should be destroyable" unless vl.is_destroyable?
   vl.nics.push Nic.new
   flunk "Vlan with nics should not be destroyable" if vl.is_destroyable?
   vl.nics.clear
   vl.bondings.push Bonding.new
   flunk "Vlan with bondings should not be destroyable" if vl.is_destroyable?
  end
end
