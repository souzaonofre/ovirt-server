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
  import org.ovirt.data.DataSource;
  import mx.containers.Box;
  import org.ovirt.data.DataSeries;
  import org.ovirt.data.FlexchartDataTransferObject;

  public class Chart {

    protected var container:Box;
    protected var dataSource:DataSource;

    protected var startTime:Number;
    protected var endTime:Number;
    protected var target:String;
    protected var id:int;
    protected var dataFunction:String;
    protected var resolution:int;

    /*
      Inheritable functions that generally do not need overrides
    */
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

    public function setDataFunction(dataFunction:String):void {
      this.dataFunction = dataFunction;
    }

    public function setResolution(resolution:int):void {
      this.resolution = resolution;
    }

    public function load():void {
      var dto:FlexchartDataTransferObject = new FlexchartDataTransferObject();
      setRequestAttributes(dto);
      dataSource.retrieveData(dto);
    }

    /*
      Constructors
    */
    public function Chart(container:Box, datasourceUrl:String) {
      this.container = container;
      initializeDataSource();
      if (datasourceUrl != null) {
        var results:Array = datasourceUrl.split("/");
        if (results != null && results.length > 8) {
          setId(new int(results[4]));
          setTarget(results[5] as String);
          setStartTime(new int(results[6]));
          setEndTime(new int(results[7]));
          setDataFunction(results[8] as String);
        }
      }
    }

    /*
      Functions that subclasses should override
      (ActionScript does not offer abstract methods)
    */
    protected function initializeDataSource():void {
    }

    //subclasses should override this
    protected function setRequestAttributes(dto:FlexchartDataTransferObject):void {
    }

    public function addData(dataSeries:DataSeries):void {
    }

  }
}
