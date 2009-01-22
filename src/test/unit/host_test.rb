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

class HostTest < Test::Unit::TestCase
  fixtures :hosts
  fixtures :pools
  fixtures :vms

  def setup
     @host = Host.new(
         :uuid => 'foobar',
         :hostname => 'foobar',
         :arch => 'x86_64',
         :hypervisor_type => 'KVM',
         :state => 'available')

      @host.hardware_pool = pools(:corp_com)
  end

  def test_valid_fails_without_hardware_pool
      @host.hardware_pool = nil

      flunk "Hosts must be associated w/ a hardware pool" if @host.valid?
  end

  def test_valid_without_uuid
       @host.uuid = nil

       flunk "Hosts don't need to be associated w/ a uuid" unless @host.valid?
  end


  def test_valid_fails_without_hostname
       @host.hostname = ''

       flunk "Hosts must be associated w/ a hostname" if @host.valid?
  end


  def test_valid_fails_without_arch
       @host.arch = ''

       flunk "Hosts must be associated w/ an arch" if @host.valid?
  end

  def test_valid_fails_with_bad_hypervisor_type
       @host.hypervisor_type = 'foobar'

       flunk "Hosts must be associated w/ a valid hypervisor type" if @host.valid?
  end

  def test_valid_fails_with_bad_state
       @host.state = 'foobar'

       flunk "Hosts must be associated w/ a valid state" if @host.valid?
  end

  def test_host_movable
       assert_equal @host.movable?, true, "Hosts are movable unless associated w/ vms"

       @host.vms << vms(:production_httpd_vm)
       assert_equal @host.movable?, false, "Hosts with associated vms are not movable"
  end

end
