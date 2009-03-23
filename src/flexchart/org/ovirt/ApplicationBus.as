/*
 Copyright (C) 2008 Red Hat, Inc.
 Written by Steve Linabery <slinabery@redhat.com>

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2 of the License.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 MA  02110-1301, USA.  A copy of the GNU General Public License is
 also available at http://www.gnu.org/copyleft/gpl.html.
*/

//A way to expose some functions that are defined in flexchart.mxml to
//our ActionScript classes without needing to access Application directly

package org.ovirt {

  import org.ovirt.charts.BarChart;
  import org.ovirt.charts.HostChart;

  public class ApplicationBus {

    private static var _instance:ApplicationBus;

    public static function instance():ApplicationBus {
      if (_instance == null) {
        _instance = new ApplicationBus();
      }
      return _instance;
    }

    public var mainChartBarClickAction:Function;
    public var closeHostChart:Function;

    public var mainChart:BarChart;
    public var hostChart:HostChart;

  }
}
