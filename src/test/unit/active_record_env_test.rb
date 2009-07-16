#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Jason Guiditta <jguiditt@redhat.com>
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
require File.dirname(__FILE__) + '/../../dutils/active_record_env'

class ActiveRecordEnvTest < ActiveSupport::TestCase
  fixtures :pools, :hosts, :vms, :boot_types,
    :networks, :nics, :ip_addresses, :privileges, :roles, :permissions,
    :quotas, :storage_pools, :storage_volumes, :tasks

  def test_can_find_hosts
    database_connect
    hosts = Host.find(:all, :limit => 2)
    assert_not_nil hosts, 'you have no hosts list!'
  end

#  def test_can_get_nested_set
#    pools = HardwarePool.get_default_pool.full_set_nested(:method => :json_hash_element,
#                       :privilege => Permission::PRIV_VIEW, :user => get_login_user)
#    flunk 'pools contains: ' << pools.inspect
#  end
end
