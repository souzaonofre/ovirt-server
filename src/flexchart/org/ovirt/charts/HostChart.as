/*
 Copyright (C) 2009 Red Hat, Inc.
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
  import flash.display.Graphics;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import mx.collections.ArrayCollection;
  import mx.containers.Box;
  import mx.containers.HBox;
  import mx.containers.VBox;
  import mx.containers.Canvas;
  import mx.controls.TextInput;
  import mx.controls.DateField;
  import mx.controls.Button;
  import mx.controls.Label;
  import mx.controls.PopUpMenuButton;
  import mx.controls.Text;
  import mx.events.MenuEvent;
  import mx.events.FlexEvent;
  import mx.formatters.DateFormatter;
  import org.ovirt.data.*;
  import org.ovirt.elements.*;
  import org.ovirt.Constants;
  import org.ovirt.ApplicationBus;
  import mx.core.ScrollPolicy;

  public class HostChart extends Chart {

    private var yScale:Scale;
    private var navBar:HBox;
    private var chartFrame:HBox;
    private var chartArea:Canvas;
    private var XAxisLabelArea:Canvas;

    //this has to happen after the scale area has been rendered, or it will have no width.
    private function drawLine(event:Event):void {
      var xg:Graphics = XAxisLabelArea.graphics;
      xg.beginFill(Constants.axisColor);
      xg.lineStyle(1,Constants.axisColor);
      xg.moveTo(yScale.width,0);
      xg.lineTo(Constants.width,0);
      xg.endFill();
    }


    /*
      Constructors
    */
    public function HostChart(container:Box) {
      super(container,null);
    }

    /*
      Overriden functions
    */
    override protected function initializeDataSource():void {
      dataSource = new HostChartDataSource(this);
    }

    override protected function setRequestAttributes(dto:FlexchartDataTransferObject):void {
      dto.setId(id);
      dto.setTarget(target);
      dto.setStartTime(startTime);
      dto.setResolution(resolution);
      dto.setDataFunction(dataFunction);
    }

    override public function addData(dataSeries:DataSeries):void {
      container.removeAllChildren();

      var i:int;
      var yLabelPercentWidth:int = 8;

      var myDate:Date = new Date();
      myDate.setTime(startTime * 1000);
      var dateFormat:DateFormatter = new DateFormatter();
      dateFormat.formatString = "JJ:NN DD-MMM-YYYY";

      navBar = new HBox();
      navBar.setStyle("horizontalGap","1");
      navBar.height = 20;
      navBar.percentWidth = 100;
      navBar.setVisible(true);
      var navBarLabel:Label = new Label();
      navBarLabel.text = "Host status at " + dateFormat.format(myDate);
      navBar.addChild(navBarLabel);

      var closeLink:Label = new Label();
      closeLink.setStyle("color","0x2875c1");
      closeLink.setStyle("textDecoration","underline");
      closeLink.text = "Close";
      navBar.addChild(closeLink);
      this.container.addChild(navBar);

      chartFrame = new HBox();
      chartFrame.percentHeight = 80;
      chartFrame.percentWidth = 100;
      chartFrame.setVisible(true);
      chartFrame.setStyle("horizontalGap","1");

      yScale = new Scale();
      yScale.percentHeight = 100;
      yScale.percentWidth = yLabelPercentWidth;
      yScale.setVisible(true);

      chartArea = new Canvas();
      chartArea.percentHeight = 100;
      chartArea.percentWidth = 100 - yLabelPercentWidth;
      chartArea.setStyle("backgroundColor","0xffffff");

      chartArea.verticalScrollPolicy = ScrollPolicy.OFF

      chartFrame.addChild(yScale);
      chartFrame.addChild(chartArea);
      chartFrame.addEventListener(FlexEvent.CREATION_COMPLETE,drawLine);
      this.container.addChild(chartFrame);

      XAxisLabelArea = new Canvas();
      XAxisLabelArea.height = Constants.labelHeight;
      XAxisLabelArea.minHeight = Constants.labelHeight;
      XAxisLabelArea.percentWidth = 100;
      this.container.addChild(XAxisLabelArea);

      try {
        var dataPoints:Array = dataSeries.getDataPoints();
        var size:int = dataPoints.length;
        if (size == 0) {
          throw new Error("No data points in range");
        }

        var maxValue:Number = dataSeries.getMaxValue();
        var scale:Number = maxValue;
        yScale.setMax(maxValue);
        //avoid divide by zero
        if (scale == 0) {
          scale = 1;
        }

	var calculatedWidth:Number = Constants.width * (chartArea.percentWidth / 100.0) ;

        //the distance between left edges of adjacent bars
        var gridWidth:Number = Math.floor(calculatedWidth / size);

        //the width of each SingleBar (does not including padding between bars)
        var barWidth:Number = gridWidth - Constants.barSpacing;

        //due to the discrete number of pixels, there may be space at the
        //right side of the graph that needs to be made up by padding
        //bars here and there
	var shortfall:Number = calculatedWidth - (gridWidth * size);
	var makeup:Number = Math.round(size / shortfall);
	var madeup:Number = 0;

        //variable to hold the x-coordinate of the next bar to be added to
        //the chart
	var currentBarPosition:int = 0;

        //add the bars & labels to the chart
        var labelCounter:int = 0;
        for (i = 0; i < size; i++) {

          var dataPoint:DataPoint = dataPoints[i] as DataPoint;

          var bar:SingleBar = new SingleBar(dataPoint,scale);
          bar.setColor(Constants.hostsBarColor)
          bar.setLitColor(Constants.hostsBarLitColor)
          chartArea.addChild(bar);
          bar.width = barWidth;
	  bar.x = currentBarPosition;
          if (makeup > 0 && i % makeup == 0 && madeup < shortfall) {
            bar.width = bar.width + 1;
            madeup++;
          }

          //if there aren't many bars, make them thinner.
          if (size < 4) {
            var tempWidth:Number = bar.width;
            var tempX:Number = bar.x;

            bar.width = bar.width * .8;
            bar.x = tempX + tempWidth * .1;
          }


          var label:XAxisLabel =
            new XAxisLabel(dataPoint.getNodeName());
	  label.setCenter(bar.x + bar.width / 2);
          label.setVisible(true);
          label.y = 6;
          XAxisLabelArea.addChild(label);
          currentBarPosition += (bar.width + Constants.barSpacing);
        }
      } catch (e:Error) {
        trace(e.getStackTrace())
      }
    }

  }
}
