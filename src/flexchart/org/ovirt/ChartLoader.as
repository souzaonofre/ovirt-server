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

  import mx.containers.Box;
  import mx.containers.HBox;
  import mx.controls.Text;

  public class ChartLoader {

    private var element:Box;
    private var datasourceUrl:String;

    public function ChartLoader(element:Box, datasourceUrl:String) {
      this.element = element;
      this.datasourceUrl = datasourceUrl;
    }

    public function addData(dataSeries:DataSeries):void {
      var points:Array = dataSeries.getPoints();
      var maxValue:Number = dataSeries.getMaxValue();
      var scale:Number = maxValue;
      if (scale == 0) { scale = 1; }
      var size:int = points.length;
      element.removeAllChildren();
      element.setStyle("horizontalGap","2");
      for (var i:int = 0; i < size; i++) {
        var value:Number = (points[i] as Array)[1];
        var bar:HBox = new HBox();
        bar.percentHeight = ((value / scale) * 90);
        bar.percentWidth = (100 / size);
        bar.setStyle("backgroundColor","0x0000FF");
        bar.setStyle("left","1");
        bar.setStyle("right","1");
        bar.visible = true;
        bar.setVisible(true);
        element.addChild(bar);
      }
    }

    public function load():void {
      var dataSource:DataSource = new DataSource(this);
      dataSource.retrieveData(datasourceUrl);
    }
  }
}