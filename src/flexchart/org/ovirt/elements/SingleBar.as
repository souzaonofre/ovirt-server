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

  import mx.containers.Box;
  import mx.controls.ToolTip;
  import mx.managers.ToolTipManager;
  import flash.events.Event;
  import flash.events.MouseEvent;
  import flash.geom.Rectangle;
  import flash.display.DisplayObject;
  import org.ovirt.data.DataPoint;

  public class SingleBar extends Box {

    private var tip:ToolTip;
    private var dataPoint:DataPoint;

    public function SingleBar(dataPoint:DataPoint) {
      super();
      this.dataPoint = dataPoint;
      addEventListener(MouseEvent.MOUSE_OVER,showTip);
      addEventListener(MouseEvent.MOUSE_OUT,destroyTip);
      this.setStyle("backgroundColor","0x0000FF");
      this.setStyle("left","1");
      this.setStyle("right","1");
    }

    private function showTip(event:Event):void {
      var w:Number = this.stage.width;
      var target:DisplayObject = event.currentTarget as DisplayObject;
      var pt:Rectangle = this.stage.getBounds(target);
      var yPos:Number = pt.y * -1;
      var xPos:Number = pt.x * -1;
      tip = ToolTipManager.createToolTip(dataPoint.getDescription() + "\n" +
                                           dataPoint.getTimestamp() + "\n" +
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
  }
}
