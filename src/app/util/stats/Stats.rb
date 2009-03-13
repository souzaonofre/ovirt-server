#!/usr/bin/ruby
# 
# Copyright (C) 2008 Red Hat, Inc.
# Written by Mark Wagner <mwagner@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

require 'RRD'
require 'util/stats/StatsTypes'
require 'util/stats/StatsData'
require 'util/stats/StatsDataList'
require 'util/stats/StatsRequest'

# This fetches a rolling average, basically average points before and after.



def fetchRollingAve?(rrdPath, start, endTime, interval, myFunction, lIndex, returnList, aveLen=7)
   final = 0
   my_min = 0
   my_max = 0

   #  OK, first thing we need to do is to move the start time back in order to 
   #  have data to average.
       
   indexOffset = ( aveLen / 2 ).to_i
   start -= ( interval  * indexOffset)

   (fstart, fend, names, data, interval) = RRD.fetch(rrdPath, "--start", start.to_s, \
                             "--end", endTime.to_s, myFunction, "-r", interval.to_s)
   returnList.set_interval interval
   i = 0
   # For some reason, we get an extra datapoint at the end.  Just chop it off now...
   data.delete_at(-1)

   # OK, to support callable average lengths, lets use an array
   #  Ruby lets you do some nice things (did I just say that ?) 
   # to manipulate the array so exploit it
 
   roll = []

   # Now, lets walk the returned data and create the objects, and put them in a list.
   data.each do |vdata|
      i += 1
      final = 0
      value = 0
      value = vdata[lIndex]
      value = 0 if value.is_?(Float) && value.nan?
 

      roll.push(value)
      if ( i >= aveLen)
         #  OK, now we need to walk the array and sum the values
         # then divide by the length and stick it in the list
         roll.each do |rdata|
            final += rdata
         end
         final = (final / aveLen )

         # Determine min / max to help with autoscale.
         unless final.is_a?(Float) && final.nan?
           my_min = [my_min, final].min
           my_max = [my_max, final].max
         end
         returnList.append_data( StatsData.new(fstart + interval * ( i - indexOffset), final ))
 
         # Now shift the head off the array
         roll.shift
      end
   end

   # Now add the min / max to the lists
   returnList.set_min_value(my_min)
   returnList.set_max_value(my_max)

 return returnList
end


def fetchRollingCalcUsedData?(rrdPath, start, endTime, interval, myFunction, lIndex, returnList, aveLen=7)

   my_min = 0
   my_max = 0

   # OK, first thing we need to do is to move the start time back in order to have data to average.
      
   indexOffset = ( aveLen / 2 ).to_i
   start -= ( interval  * indexOffset)

   lFunc = "AVERAGE"   
   case myFunction
      when "MAX"
         lFunc="MIN"
      when "MIN"
         lFunc="MAX"
   end

   (fstart, fend, names, data, interval) = RRD.fetch(rrdPath, "--start", start.to_s, \
                             "--end", endTime.to_s, lFunc, "-r", interval.to_s)
   returnList.set_interval interval
   i = 0
   # For some reason, we get an extra datapoint at the end.  Just chop it off now...
   data.delete_at(-1)

   roll = []

   # Now, lets walk the returned data and create the objects, and put them in a list.
   data.each do |vdata|
      i += 1
      final = 0
      value = 0
      value = vdata[lIndex]
      value = 100 if value.is_a?(Float) && value.nan?
      if ( value > 100 )
         value = 100
      end

      value = 100 - value

      roll.push(value)
      if ( i >= aveLen)
         #  OK, now we need to walk the array and sum the values
         # then divide by the length and stick it in the list
         roll.each do |rdata|
            final += rdata
         end
         final = (final / aveLen)

         # Determine min / max to help with autoscale.
         unless final.is_a?(Float) && final.nan?
           my_min = [my_min, final].min
           my_max = [my_max, final].max
         end
         returnList.append_data( StatsData.new(fstart + interval * ( i - indexOffset), final ))
         # Now shift the head off the array
         roll.shift
      end
   end

   # Now add the min / max to the lists
   returnList.set_min_value(my_min)
   returnList.set_max_value(my_max)

 return returnList
end


def fetchCalcUsedData?(rrdPath, start, endTime, interval, myFunction, lIndex, returnList)

   #  OK, this is a special to massage the data for CPU:CalcUsed
   #  Basically we  take the Idle time and subtract it from 100
   #  We also need to handle NaN differently 
   #  Finally, we need to switch Min and Max
 
   my_min = 0
   my_max = 0

   lFunc = "AVERAGE"   
   case myFunction
      when "MAX"
         lFunc="MIN"
      when "MIN"
         lFunc="MAX"
   end

   (fstart, fend, names, data, interval) = RRD.fetch(rrdPath, "--start", start.to_s, \
                                  "--end", endTime.to_s, lFunc, "-r", interval.to_s)
   returnList.set_interval interval
   i = 0 
   # For some reason, we get an extra datapoint at the end.  Just chop it off now...
   data.delete_at(-1)

   # Now, lets walk the returned data and create the ojects, and put them in a list.
   data.each do |vdata|
      i += 1
      value = vdata[lIndex]
      value = 100 if value.is_a?(Float) && value.nan?
      if ( value > 100 )
         value = 100
      end
      value  =  100 - value

      # Determine min / max to help with autoscale.
      unless value.is_a?(Float) && value.nan?
        my_min = [my_min, value].min
        my_max = [my_max, value].max
      end
      returnList.append_data( StatsData.new(fstart + interval * i, value ))
   end

   # Now add the min / max to the lists
   returnList.set_min_value(my_min)
   returnList.set_max_value(my_max)
   
 return returnList
end


def fetchRegData?(rrdPath, start, endTime, interval, myFunction, lIndex, returnList)

   my_min = 0
   my_max = 0

   (fstart, fend, names, data, interval) = RRD.fetch(rrdPath, "--start", start.to_s, "--end", \
                                               endTime.to_s, myFunction, "-r", interval.to_s)
   returnList.set_interval interval
   i = 0 
   # For some reason, we get an extra datapoint at the end.  Just chop it off now...
   data.delete_at(-1)

   # Now, lets walk the returned data and create the ojects, and put them in a list.
   data.each do |vdata|
      value = vdata[lIndex]
      i += 1
      unless value.is_a?(Float) && value.nan?
        my_min = [my_min, value].min
        my_max = [my_max, value].max
      end
      returnList.append_data( StatsData.new(fstart + interval * i, value ))
   end

   # Now add the min / max to the lists
   returnList.set_min_value(my_min)
   returnList.set_max_value(my_max)
   
 return returnList
end


def fetchData?(node, devClass, instance, counter, startTime, duration, interval, function)

   endTime = 0

   if (interval == 0)
      interval = RRDResolution::Default
   end

   
   if (startTime == 0)
      if (duration > 0 )
         sTime = Time.now.to_i - duration
      else
         sTime = Time.now.to_i - 86400 
      end
      eTime = Time.now.to_i  
   else
      sTime = startTime
      eTime = sTime + duration
   end 
   # Now mangle based on the intervals

   start =  (sTime / interval).to_i * interval 
   endTime =  (eTime / interval).to_i * interval 

   rrdBase="/var/lib/collectd/rrd/"
   rrdNode=rrdBase + node + "/"

   # Now we need to mess a bit to get the right combos
   case devClass
    when DevClass::CPU
       rrdTail = CpuCounter.getRRDPath(instance, counter)
       lIndex = CpuCounter.getRRDIndex(counter)
    when DevClass::Memory
       rrdTail = MemCounter.getRRDPath(instance, counter)
       lIndex = MemCounter.getRRDIndex(counter)
    when DevClass::Load
       rrdTail = LoadCounter.getRRDPath(instance, counter)
       lIndex = LoadCounter.getRRDIndex(counter)
    when DevClass::NIC
       rrdTail = NicCounter.getRRDPath(instance, counter)
       lIndex = NicCounter.getRRDIndex(counter)
    when DevClass::Disk
       rrdTail = DiskCounter.getRRDPath(instance, counter)
       lIndex = DiskCounter.getRRDIndex(counter)
    else
       puts "Nothing for devClass"
    end

    rrd = rrdNode + rrdTail + ".rrd"

    if ( File.exists?(rrd ) )
       localStatus = StatsStatus::SUCCESS
    elsif ( File.exists?(rrdNode ))
       # Check the Node first
       localStatus = StatsStatus::E_NOSUCHNODE
    else
       # Currently can't distinguish between device and counter, so return generic error 
       localStatus = StatsStatus::E_UNKNOWN
   end
   
    case function
       when DataFunction::Peak 
          myFunction="MAX"
       when DataFunction::Min 
          myFunction="MIN"
       when DataFunction::RollingPeak 
          myFunction="MAX"
       when DataFunction::RollingMin 
          myFunction="MIN"
       else
          myFunction="AVERAGE"
    end

   returnList = StatsDataList.new(node,devClass,instance, counter, localStatus, function, interval)

   if ( localStatus == StatsStatus::SUCCESS )
      if ( function == DataFunction::RollingPeak) || 
         ( function == DataFunction::RollingMin) || 
         ( function == DataFunction::RollingAverage)
         if ( devClass == DevClass::CPU ) && ( counter == CpuCounter::CalcUsed )
            fetchRollingCalcUsedData?(rrd, start, endTime, interval, myFunction, lIndex, returnList)
         else
            fetchRollingAve?(rrd, start, endTime, interval, myFunction, lIndex, returnList)
         end
      else
         if ( devClass == DevClass::CPU ) && ( counter == CpuCounter::CalcUsed )
            fetchCalcUsedData?(rrd, start, endTime, interval, myFunction, lIndex, returnList)
         else
            fetchRegData?(rrd, start, endTime, interval, myFunction, lIndex, returnList)
         end
      end
   end
   return returnList

end





def  getStatsData?(statRequestList)
    tmpList = []
    
    myList = []
    statRequestList.each do |request|
       node = request.get_node?
       counter = request.get_counter?
       tmpList =fetchData?(request.get_node?, request.get_devClass?,request.get_instance?, request.get_counter?, \
                     request.get_starttime?, request.get_duration?,request.get_precision?, request.get_function?)
 
       #  Now copy the array returned into the main array
       myList << tmpList
    end

return myList

end

# This function aggregates all of the values returned into one list before
# returning.  It is up to the caller to ensure that the request list has
# "like" items.  For instance if you request CPU Utilization and Network bytes,
# this function will be happy to aggregate them for you...

def  getAggregateStatsData?(statRequestList)

    tmpList = []
    myMasterList = []
    myList = []
    my_min = 0
    my_max = 0
    value = 0

    resolution = 0

    node = "Aggregate"
    returnList = StatsDataList.new("Aggregate", 0, 0, 0, 0, 0, 0)
    statRequestList.each do |request|
       #all aggregates need to have the same interval/resolution/precision
       if resolution == 0
         resolution = request.get_precision?
       end
       node = request.get_node?
       counter = request.get_counter?
       tmpList =fetchData?(request.get_node?, request.get_devClass?,request.get_instance?, request.get_counter?, \
                     request.get_starttime?, request.get_duration?,request.get_precision?, request.get_function?)
       #if the interval/resolution/precision varies, raise an exception
       if request.get_precision? != resolution
         raise
       end
       #  Now for something completely different...
       #  The first list back will become our "master"
       #  Each successive list will be proccesed against the master
       #  as appropriate.

       # Keep in mind the following things:
       # 1) The lists coming in are already "normalized" for their respective types
       #    So no need to worry about calculated values, etc.
       # 2) Each list will have a min and max value set. Just use those values
       #    when possible.

          idx = 0

          list = tmpList.get_data?()
          list.each do |d|

             #  A NaN will really screw things up, so lets terminate
             #  them with extreme prejudice...

             value = d.get_value?
             value = 0 if value.is_a?(Float) && value.nan?

             if (myMasterList.length > idx )
                if ( d.get_timestamp? > myMasterList[idx].get_timestamp? )
                   spin = 1

                   # Now we try to sync the pointers between the two lists
                   # Need to move the pointer to the master list
                   # We don't actually set anything in the list,
                   # just position the pointers as best as we can

                   while ( spin == 1)
                      if ( idx  >= myMasterList.length - 1)
                         # Can't go any further in the master
                         # Will just need to append
                         spin = 0
                      else
                         if ( d.get_timestamp? > myMasterList[idx].get_timestamp? )
                            idx += 1 # Just move the pointer
                         else
                            spin = 0
                         end
                      end
                   end # while loop
                end

                # Now the pointers should be moved as much as possible
                # *Should* be easy to take the proper action
                if ( d.get_timestamp? == myMasterList[idx].get_timestamp? )
                   myMasterList[idx].set_value( myMasterList[idx].get_value? + value )

                elsif ( d.get_timestamp?  > myMasterList[idx].get_timestamp? )
                   # OK, so the new list has times that are greater than
                   # what is in the master. append them to the end.
                   myMasterList <<  StatsData.new(d.get_timestamp?, value )

                else #  myMasterList[idx].get_timestamp? > d.get_timestamp?
                   # Insert at the current location
                   myMasterList.insert(idx, StatsData.new(d.get_timestamp?, value ))
                end
             else
                # OK, we have reached the end of the master list
                # and still have more data. Just append.
                myMasterList <<  StatsData.new(d.get_timestamp?, value )
             end

             mvalue = myMasterList[idx].get_value?()
             unless mvalue.is_a?(Float) && mvalue.nan?
               my_min = [my_min, mvalue].min
               my_max = [my_max, mvalue].max
             end
             idx += 1
          end
       end

    # Its late at night try some brute force

    myMasterList.each do |d|
       returnList.append_data( StatsData.new(d.get_timestamp?, d.get_value? ))
    end
    returnList.set_min_value(my_min)
    returnList.set_max_value(my_max)
    returnList.set_resolution(resolution)
    myList << returnList

return myList

end

# This function also aggregates all of the values returned into one list before
# returning.  It is up to the caller to ensure that the request list has
# "like" items.  For instance if you request CPU Utilization and Network bytes,
# this function will be happy to aggregate them for you...
# This function, however, also takes a start and end time, and will pad with
# zero data points to fill any gaps in the returned data. It also returns
# the data points with regular temporal spacing based on the oldest/coarsest
# resolution available in the data.
def getPaddedAggregateStatsData?(statRequestList, startTime, endTime)

  fetchResults = []
  myList = []
  my_min = 0
  my_max = 0
  interval = 0

  node = "Aggregate"
  returnList = StatsDataList.new("Aggregate", 0, 0, 0, 0, 0, 0)
  statRequestList.each do |request|
    node = request.get_node?
    counter = request.get_counter?

    #Later time-ranged requests might have a finer resolution than earlier
    #time-ranged requests. We assume that the ActiveRecord sql will order
    #these by ascending startTime, and that the oldest rrd data will always
    #have the coarsest resolution.
    if request.get_precision? < interval
      request.set_precision interval
    end
    tmpResult = fetchData?(request.get_node?, request.get_devClass?,
                           request.get_instance?, request.get_counter?,
                           request.get_starttime?, request.get_duration?,
                           request.get_precision?, request.get_function?)
    fetchResults.push tmpResult

    if interval == 0
      interval = tmpResult.get_interval?
    end
  end

  if interval != 0

    sTime =  (startTime.to_i / interval).to_i * interval
    eTime =  (endTime.to_i / interval).to_i * interval
    pointCount = ((eTime - sTime) / interval) + 1

    #ensure the results are sorted for the following loop
    fetchResults.sort! {|x,y|
      xTime = x.get_data?.empty? ? 0 : x.get_data?[0].get_timestamp?
      yTime = y.get_data?.empty? ? 0 : y.get_data?[0].get_timestamp?
      xTime <=> yTime
    }

    myCount = 0
    while myCount < pointCount do
      myTime = sTime + interval * (myCount + 1)
      newDatum = StatsData.new(myTime,0)

      fetchResults.each do |result|
        if (! result.get_data?.empty?) &&
            result.get_data?[0].get_timestamp? == myTime

          datum = result.get_data?.shift
          myValue = datum.get_value?.is_a?(Float) && datum.get_value?.nan? ? 0 : datum.get_value?
          newDatum.set_value(newDatum.get_value? + myValue)
        end
      end
      returnList.append_data(newDatum)

      my_min = [my_min, newDatum.get_value?].min
      my_max = [my_max, newDatum.get_value?].max
      myCount += 1
    end

    returnList.set_min_value(my_min)
    returnList.set_max_value(my_max)
    returnList.set_interval(interval)
  end

  myList << returnList
  return myList

end
