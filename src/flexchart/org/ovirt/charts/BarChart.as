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

  import mx.containers.Box;
  import mx.containers.HBox;
  import mx.containers.VBox;
  import mx.controls.Text;
  import mx.containers.Canvas;
  import org.ovirt.data.*;
  import org.ovirt.elements.*;
  import org.ovirt.Constants;

  public class BarChart extends Chart {

    private var chartArea:HBox;
    private var labelArea:Canvas;

    public function BarChart(container:Box,
                             datasourceUrl:String) {
      super(container,datasourceUrl);
      chartArea = new HBox();
      chartArea.setStyle("horizontalGap",Constants.barSpacing);
      chartArea.setStyle("verticalAlign","bottom");
      chartArea.percentHeight = 80;
      chartArea.percentWidth = 100;
      this.container.addChild(chartArea);

      labelArea = new Canvas();
      labelArea.height = Constants.labelHeight;
      labelArea.minHeight = Constants.labelHeight;
      labelArea.percentWidth = 100;
      this.container.addChild(labelArea);
    }

    override public function addData(dataSeries:DataSeries):void {
      try {
        var dataPoints:Array = dataSeries.getDataPoints();
        var maxValue:Number = dataSeries.getMaxValue();
        var scale:Number = maxValue;
        //avoid divide by zero
        if (scale == 0) {
          scale = 1;
        }
        var size:int = dataPoints.length;
        if (size == 0) {
          throw new Error("No data points in range");
        }

        //have to iterate through datapoint.timestamp strings,
        //create a TextLiberation object with them, and add them to
        //a parent container before we can tell how wide they are in pixels.
        var labelWidth:Number = 0;
        for (var i:int = 0; i < size; i++) {
          var dataPoint:DataPoint = dataPoints[i] as DataPoint;
          var textTemp:TextLiberation =
            new TextLiberation(dataPoint.getTimestamp());
          textTemp.setVisible(false);
          chartArea.addChild(textTemp);
          var tempLabelWidth:Number = textTemp.getTextWidth();
          if (! isNaN(tempLabelWidth)) {
            labelWidth = Math.max(labelWidth, tempLabelWidth);
          }
        }
        //now we have to remove all the children we just added, since we don't
        //really want them to be part of the chart.
        chartArea.removeAllChildren();

        //we always want an odd number of y-axis labels, and we'll
        //determine this by using the labelWidth we just determined
        var labelCount:int = Math.floor(Constants.width / labelWidth);
        if (labelCount > 3 && labelCount % 2 == 1) {
          labelCount--;
        }

        //the distance between left edges of adjacent bars
        var gridWidth:Number = Constants.width / size;

        //the width of each SingleBar (does not including padding between bars)
        var barWidth:Number = gridWidth - Constants.barSpacing;

        //use this to center y-axis labels on the bars
        var labelOffset:Number = barWidth / 2;

        //distance between first and last label
        var labelSpace:Number = Constants.width - gridWidth;
        var labelSpacing:Number = labelSpace / labelCount;

        //add the bars & labels to the chart
        var labelCounter:int = 0;
        for (i = 0; i < size; i++) {
          dataPoint = dataPoints[i] as DataPoint;
          var value:Number = dataPoint.getValue();
          var bar:SingleBar = new SingleBar(dataPoint);
          bar.percentHeight = ((value / scale) * 80);
          bar.width = barWidth;
          bar.setVisible(true);
          chartArea.addChild(bar);
          var currentLabelPosition:int = labelCounter * labelSpacing +
                                           labelOffset;

          if (currentLabelPosition >= i * gridWidth &&
                currentLabelPosition < (i + 1) * gridWidth) {
            var label:YAxisLabel = new YAxisLabel(dataPoint.getTimestamp());
            label.setVisible(false);
            label.y = ((labelCounter + 1) % 2) * 13 + 4;
            labelArea.addChild(label);
            //make sure the label is fully within the chart width
            label.x = Math.max(0,
                               Math.min((i) * gridWidth -
                                 (label.labelText.getTextWidth() / 2) +
                                 labelOffset,
                               Constants.width -
                                 label.labelText.getTextWidth() - 6)
                              );
            label.setVisible(true);
            labelCounter++;

            //add a 'tick' in the center of the bar to which this label
            //corresponds
            var ind:Box = new Box();
            ind.opaqueBackground = 0x000000;
            ind.width=1;
            ind.height=3;
            ind.x =  (i) * gridWidth + labelOffset;
            ind.y = 0;
            ind.setVisible(true);
            ind.setStyle("backgroundColor","0x000000");
            labelArea.addChild(ind);
          }
        }
      } catch (e:Error) {
        var err:Text = new Text();
        err.text = e.message;
        err.setVisible(true);
        chartArea.addChild(err);
      }
    }
  }
}
