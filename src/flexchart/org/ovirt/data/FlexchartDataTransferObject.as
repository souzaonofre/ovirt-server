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

package org.ovirt.data {

  public class FlexchartDataTransferObject {

    private var startTime:int;
    private var endTime:int;
    private var id:int;
    private var target:String;
    private var resolution:int;
    private var averageLength:int;
    private var dataFunction:String;

    public function setStartTime(startTime:int):void {
      this.startTime = startTime;
    }

    public function getStartTime():int {
      return startTime;
    }

    public function setEndTime(endTime:int):void {
      this.endTime = endTime;
    }

    public function getEndTime():int {
      return endTime;
    }

    public function setId(id:int):void {
      this.id = id;
    }

    public function getId():int {
      return id;
    }

    public function setTarget(target:String):void {
      this.target = target;
    }

    public function getTarget():String {
      return target;
    }

    public function setResolution(resolution:int):void {
      this.resolution = resolution;
    }

    public function getResolution():int {
      return resolution;
    }

    public function setAverageLength(averageLength:int):void {
      this.averageLength = averageLength;
    }

    public function getAverageLength():int {
      return averageLength;
    }

    public function setDataFunction(dataFunction:String):void {
      this.dataFunction = dataFunction;
    }

    public function getDataFunction():String {
      return dataFunction;
    }

  }
}
