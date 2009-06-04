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
  import flash.display.Graphics;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import flash.geom.Rectangle;
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

  public class BarChart extends Chart {

    private var yScale:Scale;
    private var chartFrame:HBox;
    private var chartArea:Canvas;
    private var XAxisLabelArea:Canvas;
    private var startDateField:DateField;
    private var endDateField:DateField;
    private var startTimeField:TextInput;
    private var endTimeField:TextInput;
    private var button:Button;
    private var menu:PopUpMenuButton;
    private var functionMenu:PopUpMenuButton;
    private var dateBar:Box;
    private var datePattern:RegExp;
    private var selectedBar:SingleBar;

    /*
       Private, class-specific functions
    */

    //this has to happen after the scale area has been rendered, or it will have no width.
    private function drawLine(event:Event):void {
      var xg:Graphics = XAxisLabelArea.graphics;
      xg.beginFill(Constants.axisColor);
      xg.lineStyle(1,Constants.axisColor);
      xg.moveTo(yScale.width,0);
      xg.lineTo(Constants.width,0);
      xg.endFill();
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

      //close the host chart when updating top chart
      ApplicationBus.instance().closeHostChart.call(null,event);
      load();
    }

    private function selectClickedBar(event:MouseEvent):void {
      if (selectedBar) {
        selectedBar.deselect();
      }
      selectedBar = event.target as SingleBar;
      selectedBar.select();
    }

    private function updateHostChart(event:MouseEvent):void {
      var hostChart:HostChart = ApplicationBus.instance().hostChart;
      hostChart.setId(id);
      hostChart.setTarget(target);
      hostChart.setStartTime((event.target as SingleBar).getStartTime() / 1000);
      hostChart.setResolution((event.target as SingleBar).getResolution());
      hostChart.setDataFunction(dataFunction);
      hostChart.load();
    }

    private function typeSelected(event:MenuEvent):void {
      target = event.label;
      ApplicationBus.instance().closeHostChart.call(null,event);
      load();
    }

    private function functionSelected(event:MenuEvent):void {
      dataFunction = event.label;
      ApplicationBus.instance().closeHostChart.call(null,event);
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


    /*
      Constructors
    */
    public function BarChart(container:Box,
                             datasourceUrl:String) {
      super(container,datasourceUrl);
      container.setStyle("verticalGap","2");
      datePattern = /^(\d+):(\d+)$/;
    }

    /*
      Public functions
    */

    public function clearSelection():void {
      if (selectedBar) {
        selectedBar.deselect();
      }
      selectedBar = null;
    }

    /*
      Overriden functions
    */

    override public function load():void {
      clearSelection();
      super.load();
    }

    override protected function initializeDataSource():void {
      dataSource = new BarChartDataSource(this);
    }

    override protected function setRequestAttributes(dto:FlexchartDataTransferObject):void {
      dto.setId(id);
      dto.setTarget(target);
      dto.setStartTime(startTime);
      dto.setEndTime(endTime);
      dto.setDataFunction(dataFunction);
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
          if (kids[i] as SingleBar != null) {
            (kids[i] as SingleBar).destroy();
          }
        }
      }


      var yLabelPercentWidth:int = 8;

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

      XAxisLabelArea = new Canvas();
      XAxisLabelArea.height = Constants.labelHeight;
      XAxisLabelArea.minHeight = Constants.labelHeight;
      XAxisLabelArea.percentWidth = 100;


      var t1:Date = new Date(startTime * 1000);
      var t2:Date = new Date(endTime * 1000);

      try {

        dateBar = new HBox();
        dateBar.setVisible(true);
        this.container.addChild(dateBar);
        this.container.addChild(chartFrame);
        this.container.addChild(XAxisLabelArea);
        var dataPoints:Array = dataSeries.getDataPoints();

        var maxValue:Number = dataSeries.getMaxValue();
        var scale:Number = maxValue;
        yScale.setMax(maxValue);
        //avoid divide by zero
        if (scale == 0) {
          scale = 1;
        }
        var size:int = dataPoints.length;
        if (size == 0) {
          throw new Error("No data points in range");
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
          bar.setColor(Constants.summaryBarColor)
          bar.setLitColor(Constants.summaryBarLitColor)

          chartArea.addChild(bar);
          bar.width = barWidth;
          bar.addEventListener(MouseEvent.CLICK,
                               ApplicationBus.instance().mainChartBarClickAction);
          bar.addEventListener(MouseEvent.CLICK,
                               updateHostChart);
          bar.addEventListener(MouseEvent.CLICK,
                               selectClickedBar);

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
	    label.setCenter(currentBarPosition + bar.width / 2 + Constants.width - calculatedWidth);
            label.setVisible(true);
            label.y = 6;
            XAxisLabelArea.addChild(label);

            //add a 'tick' in the center of the bar to which this label
            //corresponds
            var ind:Box = new Box();
            ind.width=2;
            ind.height=4;
            ind.x = label.getCenter();
            ind.y = 0;
            ind.setVisible(true);
            ind.setStyle("backgroundColor",Constants.axisColorString);
            XAxisLabelArea.addChild(ind);


            lastDate = dataPoint.getTimestamp().date;
          }
          currentBarPosition += (bar.width + Constants.barSpacing);
        }

        t1 = new Date(dataPoints[0].getTimestamp().getTime());
        t2 = new Date(dataPoints[size - 1].getTimestamp().getTime());



      } catch (e:Error) {
        trace(e.message);
        if (size == 0) {
          var nopoints:Text = new Text();
          nopoints.text = "No Data Points In Range";
          nopoints.setVisible(true);
          try {
            chartArea.addChild(nopoints);
          } catch (e1:Error) {
            trace(e1.message);
          }
        }
      }

      //FIXME: these should be fetched from the graph controller so
      //that different types can be added (or restricted) dynamically
      var menuItems:ArrayCollection =
        new ArrayCollection( [{label: "cpu"},
                              {label: "disk"},
                              {label: "load"},
                              {label: "memory"},
                              {label: "netin"},
                              {label: "netout"}
                             ]);

      if (menu != null) {
        menu.removeEventListener(MenuEvent.ITEM_CLICK,typeSelected);
      }

      menu = new PopUpMenuButton();
      menu.label = target;
      menu.dataProvider = menuItems;
      menu.addEventListener(MenuEvent.ITEM_CLICK,typeSelected);
      dateBar.addChild(menu);


      var functionMenuItems:ArrayCollection =
        new ArrayCollection( [{label: "average"},
                              {label: "min"},
                              {label: "peak"},
                              {label: "rolling avg"},
                              {label: "rolling min"},
                              {label: "rolling peak"}
                             ]);

      if (functionMenu != null) {
        functionMenu.removeEventListener(MenuEvent.ITEM_CLICK,functionSelected);
      }

      functionMenu = new PopUpMenuButton();
      functionMenu.label = dataFunction;
      functionMenu.dataProvider = functionMenuItems;
      functionMenu.addEventListener(MenuEvent.ITEM_CLICK,functionSelected);
      dateBar.addChild(functionMenu);


      //fill in the time range selection bar

      var f1:Text = new Text();
      f1.text = "From:";
      dateBar.addChild(f1);

      startDateField = new DateField();
      startDateField.selectedDate = t1;
      startDateField.editable = true;
      startTimeField = new TextInput();
      startTimeField.minWidth = Constants.timeFieldWidth;
      startTimeField.maxWidth = Constants.timeFieldWidth;
      startTimeField.text = pad(t1.hours) + ":" + pad(t1.minutes);
      dateBar.addChild(startTimeField);
      dateBar.addChild(startDateField);
      var f2:Text = new Text();
      f2.text = "to";
      dateBar.addChild(f2);


      endDateField = new DateField();
      endDateField.selectedDate = t2;
      endDateField.editable = true;
      endTimeField = new TextInput();
      endTimeField.minWidth = Constants.timeFieldWidth;
      endTimeField.maxWidth = Constants.timeFieldWidth;
      endTimeField.text = pad(t2.hours) + ":" + pad(t2.minutes);
      dateBar.addChild(endTimeField);
      dateBar.addChild(endDateField);

      button = new Button();
      button.label = "go";
      button.addEventListener(MouseEvent.CLICK,timeRangeAdjusted);

      dateBar.addChild(button);
    }
  }
}
