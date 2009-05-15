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

//an object that calculates/displays tickmarks for axis scales.

package org.ovirt.elements {
  import mx.containers.Box;
  import flash.events.Event;
  import mx.events.FlexEvent;
  import mx.events.ResizeEvent;
  import mx.controls.Label;
  import org.ovirt.Constants;

  public class Scale extends Box {

    private var max:Number;
    private var maxLabel:Label;
    private var midLabel:Label;

    public function Scale() {
      super();
      opaqueBackground = 0xffffff;
      max = 0;
      addEventListener(ResizeEvent.RESIZE,myResize);
      addEventListener(FlexEvent.CREATION_COMPLETE,myResize);
      addEventListener(Event.RENDER,myResize);
      addEventListener(FlexEvent.INITIALIZE,myResize);
      addEventListener(FlexEvent.UPDATE_COMPLETE,myResize);

      maxLabel = new Label();
      maxLabel.setStyle("color",Constants.labelTextColor);
      this.addChild(maxLabel);
      maxLabel.setVisible(true);

      midLabel = new Label();
      midLabel.setStyle("color",Constants.labelTextColor);
      this.addChild(midLabel);
      midLabel.setVisible(true);


    }

    public function setMax(max:Number):void {
      this.max = max;
      maxLabel.text = max.toExponential(1);
      midLabel.text = (max / 2.0).toExponential(1);
      if (max > 0) {
        setVisible(true);
      } else {
        setVisible(false);
      }
    }

    private function myResize(event:Event):void {

      this.height = parent.height * Constants.elementPercentHeight * -1;
      this.y = parent.height;
      graphics.clear();
      graphics.beginFill(Constants.axisColor);
      graphics.lineStyle(1,Constants.axisColor);

      graphics.moveTo(width - 1,-1);
      graphics.lineTo(width - 1,height);


      graphics.moveTo(width - 4,height);
      graphics.lineTo(width - 1,height);

      graphics.moveTo(width - 4,height / 2);
      graphics.lineTo(width - 1,height / 2);
      graphics.endFill();

      maxLabel.y = height;
      midLabel.y = height / 2;

    }
  }
}
