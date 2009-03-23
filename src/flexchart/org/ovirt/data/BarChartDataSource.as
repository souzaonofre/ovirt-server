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

  import org.ovirt.charts.Chart;

  public class BarChartDataSource extends DataSource {

    public function BarChartDataSource(chart:Chart) {
      super(chart);
    }

    override protected function getUrl(dto:FlexchartDataTransferObject):String {
      var answer:String = "/ovirt/graph/flexchart_data/" + dto.getId() +
        "/" + dto.getTarget() +
        "/" + dto.getStartTime() +
        "/" + dto.getEndTime() +
	"/" + dto.getDataFunction();
      return answer;
    }

  }

}
