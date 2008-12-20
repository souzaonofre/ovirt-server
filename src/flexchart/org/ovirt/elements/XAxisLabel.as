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
  import mx.core.ScrollPolicy;
  import flash.events.*;
  import flash.events.MouseEvent;
  import mx.events.*;
  import mx.events.FlexEvent;

  public class XAxisLabel extends Box {

    public var labelText:TextLiberation;
    private var center:int;

    public function XAxisLabel(text:String) {
      super();
      labelText = new TextLiberation(text);
      labelText.setVisible(true);
      this.addChild(labelText);
      this.horizontalScrollPolicy = ScrollPolicy.OFF;
      this.verticalScrollPolicy = ScrollPolicy.OFF;
      this.setStyle("paddingLeft","0");
      this.setStyle("paddingRight","0");
      addEventListener(FlexEvent.CREATION_COMPLETE,centerLabel);
    }

    public function setCenter(center:int):void {
      this.center = center;
    }

    public function getCenter():int {
      return center;
    }

    private function centerLabel(event:Event):void {
      this.x = center - labelText.getTextWidth() / 2;
      if (parent != null) {
        if (this.x < 0) {
          this.x = 0;
        } else if (this.x > parent.width - labelText.getTextWidth() - 5) {
          this.x = parent.width - labelText.getTextWidth() - 5;
        }
      }
    }
  }
}
