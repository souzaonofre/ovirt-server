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
  public class Constants {
    public static var width:int = 722;
    public static var height:int = 297;
    public static var barSpacing:int = 2;
    public static var labelHeight:int = 20;
    public static var summaryBarColor:String = "0x2875c1";
    public static var summaryBarLitColor:String = "0x369aff";
    public static var hostsBarColor:String = "0x9fd100";
    public static var hostsBarLitColor:String = "0xc4ff00";
    public static var elementPercentHeight:Number = .98;
    public static var timeFieldWidth:int = 42;
    public static var labelTextColor:String = "0x666666";
    public static var axisColor:Number = 0xbbccdd;
    public static var axisColorString:String = "0xbbccdd";

    public static function setWidth(w:int):void {
      width = w;
    }
    public static function setHeight(h:int):void {
      height = h;
    }

  }
}
