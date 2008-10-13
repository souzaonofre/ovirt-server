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

package org.ovirt {

  import flash.net.URLLoader;
  import flash.net.URLRequest;
  import com.adobe.serialization.json.JSON;
  import flash.events.Event;
  import flash.events.IOErrorEvent;

  public class DataSource {

    private var chartLoader:ChartLoader;

    public function DataSource(chartLoader:ChartLoader) {
      this.chartLoader = chartLoader;
    }

    public function retrieveData(url:String):void {
      var loader:URLLoader = new URLLoader();
      loader.addEventListener( IOErrorEvent.IO_ERROR, this.ioError );
      loader.addEventListener( Event.COMPLETE, dataLoaded );
      var request:URLRequest = new URLRequest(url);
      loader.load(request);
    }

    private function dataLoaded(event:Event):void {
      var loader:URLLoader = URLLoader(event.target);
      var object:Object = JSON.decode(loader.data);
      var series:DataSeries = new DataSeries(object);
      chartLoader.addData(series);
    }

    private function ioError( e:IOErrorEvent ):void {
      //FIXME:
      //do something useful with this error
    }
  }
}
