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
  import mx.controls.PopUpMenuButton;
  import mx.controls.Text;
  import mx.events.MenuEvent;
  import mx.formatters.DateFormatter;
  import org.ovirt.data.*;
  import org.ovirt.elements.*;
  import org.ovirt.Constants;
  import org.ovirt.ApplicationBus;

  public class BarChart extends Chart {

    private var chartArea:Canvas;
    private var XAxisLabelArea:Canvas;
    private var startDateField:DateField;
    private var endDateField:DateField;
    private var startTimeField:TextInput;
    private var endTimeField:TextInput;
    private var button:Button;
    private var menu:PopUpMenuButton;
    private var dateBar:Box;
    private var datePattern:RegExp;


    public function BarChart(container:Box,
                             datasourceUrl:String) {
      super(container,datasourceUrl);
      container.setStyle("verticalGap","2");
      datePattern = /^(\d+):(\d+)$/;
    }


    private function timeRangeAdjusted(event:Event):void {
      var t1:Number = startDateField.selectedDate.getTime()
                      + (parseHour(startTimeField.text) * 3600 * 1000)
                      + (parseMinute(startTimeField.text) * 60 * 1000);
      setStartTime(Math.floor(t1 / 1000));
      var t2:Number = endDateField.selectedDate.getTime()
                      + (parseHour(endTimeField.text) * 3600 * 1000)
                      + (parseMinute(endTimeField.text) * 60 * 1000);
      setEndTime(Math.floor(t2 / 1000));
      load();
    }

    private function typeSelected(event:MenuEvent):void {
      target = event.label;
      load();
    }


    private function pad(input:int):String {
      if (input < 10) {
        return "0" + input;
      } else {
        return "" + input;
      }
    }

    private function parseHour(input:String):int {
      var answer:int = 0;
      try {
        var obj:Object = datePattern.exec(input);
        if (obj != null) {
          answer = int(obj[1].toString());
        }
      } catch (e:Error) {}
      return answer;
    }

    private function parseMinute(input:String):int {
      var answer:int = 0;
      try {
        var obj:Object = datePattern.exec(input);
        if (obj != null) {
          answer = int(obj[2].toString());
        }
      } catch (e:Error) {}
      return answer;
    }

    override public function addData(dataSeries:DataSeries):void {
      container.removeAllChildren();

      var dateFormat:DateFormatter = new DateFormatter();

      //since we're reusing objects, we need to get rid of stale
      //EventListener references
      if (chartArea != null) {
        var kids:Array = chartArea.getChildren();
        var i:int;
        for (i = 0; i < kids.length; i++) {
          (kids[i] as SingleBar).destroy();
        }
      }

      chartArea = new Canvas();
      chartArea.percentHeight = 80;
      chartArea.percentWidth = 100;
      chartArea.setStyle("backgroundColor","0xbbccdd");
      this.container.addChild(chartArea);

      XAxisLabelArea = new Canvas();
      XAxisLabelArea.height = Constants.labelHeight;
      XAxisLabelArea.minHeight = Constants.labelHeight;
      XAxisLabelArea.percentWidth = 100;
      this.container.addChild(XAxisLabelArea);

      try {

        dateBar = new HBox();
        dateBar.setVisible(true);
        this.container.addChild(dateBar);
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

        //the distance between left edges of adjacent bars
        var gridWidth:Number = Math.floor(Constants.width / size);

        //the width of each SingleBar (does not including padding between bars)
        var barWidth:Number = gridWidth - Constants.barSpacing;

        //due to the discrete number of pixels, there may be space at the
        //right side of the graph that needs to be made up by padding
        //bars here and there
	var shortfall:Number = Constants.width - (gridWidth * size);
	var makeup:Number = Math.round(size / shortfall);
	var madeup:Number = 0;

        //variable to hold the numbered day of the month of the last
        //XAxisLabel added to the label area
        var lastDate:Number;

        //variable to hold the x-coordinate of the next bar to be added to
        //the chart
	var currentBarPosition:int = 0;

        //add the bars & labels to the chart
        var labelCounter:int = 0;
        for (i = 0; i < size; i++) {

          var dataPoint:DataPoint = dataPoints[i] as DataPoint;
	  if (i == 0) {
            lastDate = dataPoint.getTimestamp().date;
          }

          //show long date format for first & last XAxisLabels,
          //as well as whenever the date changes
          if (i == 0 || i == size - 1
              || dataPoint.getTimestamp().date != lastDate) {
            dateFormat.formatString = "DD-MMM-YYYY JJ:NN";
          } else {
            dateFormat.formatString = "JJ:NN";
          }

          var value:Number = dataPoint.getValue();
          var bar:SingleBar = new SingleBar(dataPoint,scale);
          chartArea.addChild(bar);
          bar.width = barWidth;
          bar.addEventListener(MouseEvent.CLICK,
                               ApplicationBus.instance().barClickAction);
	  bar.x = currentBarPosition;
          if (makeup > 0 && i % makeup == 0 && madeup < shortfall) {
            bar.width = bar.width + 1;
            madeup++;
          }

          //add XAxisLabels at the endpoints of the time range,
          //as well as the center if there are more than 6 points
          //and two more if there are more than 14 points
          if ((size > 6 && i == Math.floor(size / 2))
              || (size > 14
                  && (i == Math.floor(size / 4)
                      || i == Math.floor(size * 3 / 4)))
              || i == 0
              || i == size - 1) {
            var label:XAxisLabel =
              new XAxisLabel(dateFormat.format(dataPoint.getTimestamp()));
	    label.setCenter(currentBarPosition + bar.width / 2);
            label.setVisible(true);
            label.y = 6;
            XAxisLabelArea.addChild(label);

            //add a 'tick' in the center of the bar to which this label
            //corresponds
            var ind:Box = new Box();
            ind.opaqueBackground = 0x000000;
            ind.width=1;
            ind.height=3;
            ind.x = label.getCenter();
            ind.y = 0;
            ind.setVisible(true);
            ind.setStyle("backgroundColor","0x000000");
            XAxisLabelArea.addChild(ind);
            lastDate = dataPoint.getTimestamp().date;
          }
          currentBarPosition += (bar.width + Constants.barSpacing);
        }

        //fill in the time range selection bar
        var t:Date;
        var f1:Text = new Text();
        f1.text = "View data between";
        dateBar.addChild(f1);
        t = new Date(dataPoints[0].getTimestamp().getTime());
        startDateField = new DateField();
        startDateField.selectedDate = t;
        startDateField.editable = true;
        startTimeField = new TextInput();
        startTimeField.minWidth = 50;
        startTimeField.maxWidth = 50;
        startTimeField.text = pad(t.hours) + ":" + pad(t.minutes);
        dateBar.addChild(startTimeField);
        dateBar.addChild(startDateField);
        var f2:Text = new Text();
        f2.text = "and";
        dateBar.addChild(f2);

        t = new Date(dataPoints[size - 1].getTimestamp().getTime());
        endDateField = new DateField();
        endDateField.selectedDate = t;
        endDateField.editable = true;
        endTimeField = new TextInput();
        endTimeField.minWidth = 50;
        endTimeField.maxWidth = 50;
        endTimeField.text = pad(t.hours) + ":" + pad(t.minutes);
        dateBar.addChild(endTimeField);
        dateBar.addChild(endDateField);

	button = new Button();
	button.label = "go";
	button.addEventListener(MouseEvent.CLICK,timeRangeAdjusted);
	dateBar.addChild(button);

        //FIXME: these should be fetched from the graph controller so
        //that different types can be added (or restricted) dynamically
        var menuItems:ArrayCollection =
          new ArrayCollection( [{label: "memory"},
                                {label: "cpu"},
                                {label: "load"},
                                {label: "netin"},
                                {label: "netout"},
                                {label: "disk"}
                               ]);


        if (menu != null) {
          menu.removeEventListener(MenuEvent.ITEM_CLICK,typeSelected);
        }

        menu = new PopUpMenuButton();
        menu.label = "Select Data Type";
        menu.dataProvider = menuItems;
        menu.addEventListener(MenuEvent.ITEM_CLICK,typeSelected);
        dateBar.addChild(menu);

      } catch (e:Error) {
        var err:Text = new Text();
        err.text = e.message;
        err.setVisible(true);
        chartArea.addChild(err);
      }
    }
  }
}
