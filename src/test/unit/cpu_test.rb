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

class CpuTest < ActiveSupport::TestCase
  fixtures :cpus
  fixtures :hosts

  def setup
    @cpu = Cpu.new(
        :cpu_number => 3,
        :core_number => 1,
        :number_of_cores => 1,
        :cpuid_level => 0,
        :speed => 2048,
        :vendor => 'foo',
        :model  => 'bar',
        :family => 'alpha')
    @cpu.host = hosts(:prod_corp_com)
  end

  def test_find_cpus
    assert_equal Cpu.find(:all).size, 8, "Failure retrieving all cpus"

    result = Cpu.find(cpus(:prod_corp_com_1).id)
    assert_equal result.host.id, hosts(:prod_corp_com).id
  end

  def test_valid_without_host
     @cpu.host = nil

     flunk "CPUs must be associated with hosts" if @cpu.valid?
  end

  def test_valid_with_bad_cpu_numer
     @cpu.cpu_number = -1

     flunk "cpu number must be >= 0" if @cpu.valid?
  end

  def test_valid_with_bad_core_number
     @cpu.core_number = -1

     flunk "cpu core number must be >= 0" if @cpu.valid?
  end

  def test_valid_with_bad_number_of_cores
     @cpu.number_of_cores = 0

     flunk "cpu number of cores must be > 0" if @cpu.valid?
  end

  def test_valid_with_bad_cpuid_level
     @cpu.cpuid_level = -1

     flunk "cpu id level must be >= 0" if @cpu.valid?
  end

  def test_valid_with_bad_speed
     @cpu.speed = 0

     flunk "cpu speed must be > 0" if @cpu.valid?
  end

  def test_valid_without_vendor
     @cpu.vendor = ''

     flunk "cpu vendor must be specified" if @cpu.valid?
  end

  def test_valid_without_model
     @cpu.model = ''

     flunk "cpu model must be specified" if @cpu.valid?
  end

  def test_valid_without_family
     @cpu.family = ''

     flunk "cpu family must be specified" if @cpu.valid?
  end

end
