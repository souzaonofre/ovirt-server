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

package org.ovirt.data {

  import com.adobe.serialization.json.JSON;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.net.URLLoader;
  import flash.net.URLRequest;
  import org.ovirt.charts.Chart;
  import org.ovirt.data.DataSeries;

  public class DataSource {

    private var chart:Chart;

    public function DataSource(chart:Chart) {
      this.chart = chart;
    }

    public function retrieveData(dto:FlexchartDataTransferObject):void {
      var loader:URLLoader = new URLLoader();
      loader.addEventListener(IOErrorEvent.IO_ERROR, this.ioError);
      loader.addEventListener(Event.COMPLETE, dataLoaded);
      var request:URLRequest = new URLRequest(getUrl(dto));
      loader.load(request);
    }

    private function dataLoaded(event:Event):void {
      var loader:URLLoader = URLLoader(event.target);
      var object:Object = JSON.decode(loader.data);
      var series:DataSeries = new DataSeries(object);
      chart.addData(series);
    }

    private function ioError( e:IOErrorEvent ):void {
      trace("ioError");
      //FIXME:
      //do something useful with this error
    }

    //subclasses should override
    protected function getUrl(dto:FlexchartDataTransferObject):String {
      return null;
    }

  }
}
