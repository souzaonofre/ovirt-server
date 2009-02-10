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

package org.ovirt.elements {

  import flash.display.DisplayObject;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import flash.geom.Rectangle;
  import mx.containers.Canvas;
  import mx.controls.ToolTip;
  import mx.events.FlexEvent;
  import mx.events.ResizeEvent;
  import mx.formatters.DateFormatter;
  import mx.managers.ToolTipManager;
  import org.ovirt.data.DataPoint;

  public class SingleBar extends Canvas {

    private var tip:ToolTip;
    private var dataPoint:DataPoint;
    private var scale:Number;
    private var dateFormat:DateFormatter = new DateFormatter();

    public function SingleBar(dataPoint:DataPoint,scale:Number) {
      super();
      this.dataPoint = dataPoint;
      this.scale = scale;
      addEventListener(MouseEvent.MOUSE_OVER,showTip);
      addEventListener(MouseEvent.MOUSE_OUT,destroyTip);
      addEventListener(ResizeEvent.RESIZE,myResize);
      addEventListener(FlexEvent.CREATION_COMPLETE,myResize);
      addEventListener(Event.RENDER,myResize);
      this.setStyle("backgroundColor","0x2875c1");
      dateFormat.formatString = "DD-MMM-YYYY JJ:NN";
    }

    public function destroy():void {
      removeEventListener(MouseEvent.MOUSE_OVER,showTip);
      removeEventListener(MouseEvent.MOUSE_OUT,destroyTip);
      removeEventListener(ResizeEvent.RESIZE,myResize);
      removeEventListener(FlexEvent.CREATION_COMPLETE,myResize);
      removeEventListener(FlexEvent.UPDATE_COMPLETE,myResize);
      removeEventListener(Event.RENDER,myResize);
    }


    private function myResize(event:Event):void {
       this.height = (dataPoint.getValue() / scale) * parent.height * .9 * -1;
       this.y = parent.height;
    }

    private function showTip(event:Event):void {

      var w:Number = this.stage.width;
      var target:DisplayObject = event.currentTarget as DisplayObject;
      var pt:Rectangle = this.stage.getBounds(target);
      var yPos:Number = pt.y * -1;
      var xPos:Number = pt.x * -1;
      tip = ToolTipManager.createToolTip(dataPoint.getDescription() +
                                         "\n" +
                                         dateFormat.format(dataPoint.getTimestamp()) +
                                         "\n" +
                                         dataPoint.getValue(),
                                         xPos,yPos) as ToolTip;
      tip.x = Math.min(tip.x,
                       w - tip.width);
      tip.y = Math.max(0,
                       tip.y - tip.height);
    }

    private function destroyTip(event:Event):void {
      ToolTipManager.destroyToolTip(tip);
    }

    public function getResolution():Number {
      return dataPoint.getResolution();
    }

    public function getStartTime():Number {
      return dataPoint.getTimestamp().getTime();
    }
  }
}
