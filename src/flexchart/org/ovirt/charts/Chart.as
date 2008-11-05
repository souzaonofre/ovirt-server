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

package org.ovirt.charts {

  public class Chart {

    import org.ovirt.DataSource;
    import mx.containers.Box;
    import org.ovirt.data.DataSeries;

    protected var container:Box;
    protected var datasourceUrl:String;

    public function Chart(container:Box, datasourceUrl:String) {
      this.container = container;
      this.datasourceUrl = datasourceUrl;
    }

    public function addData(dataSeries:DataSeries):void {
      //override me!
    }

    public function load():void {
      var dataSource:DataSource = new DataSource(this);
      dataSource.retrieveData(datasourceUrl);
    }
  }
}
