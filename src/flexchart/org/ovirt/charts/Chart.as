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
    import org.ovirt.DataSource;
    import mx.containers.Box;
    import org.ovirt.data.DataSeries;

  public class Chart {

    protected var container:Box;
    protected var datasourceUrl:String;

    protected var startTime:Number;
    protected var endTime:Number;
    protected var target:String;
    protected var id:int;

    public function Chart(container:Box, datasourceUrl:String) {
      this.container = container;
      this.datasourceUrl = datasourceUrl;
      if (datasourceUrl != null) {
        var results:Array = datasourceUrl.split("/");
        if (results != null && results.length > 7) {
          setId(new int(results[4]));
          setTarget(results[5] as String);
          setStartTime(new int(results[6]));
          setEndTime(new int(results[7]));
        }
      }
    }

    public function addData(dataSeries:DataSeries):void {
      //override me!
    }

    public function load():void {
      var dataSource:DataSource = new DataSource(this);
      var myString:String = "/ovirt/graph/flexchart_data/" + id + "/" + target +  "/" + startTime  + "/" + endTime;
      dataSource.retrieveData(myString);
    }

    public function setStartTime(startTime:Number):void {
      this.startTime = startTime;
    }

    public function setEndTime(endTime:Number):void {
      this.endTime = endTime;
    }

    public function setTarget(target:String):void {
      this.target = target;
    }

    public function setId(id:int):void {
      this.id = id;
    }
  }
}
