module GraphHelper

    def swf_is_present
        File.exists?(Rails.root.join('public','swfs','flexchart.swf'))
    end

    def swf_bits_download_url
        "http://ovirt.org/flexchart/flexchart.swf"
    end


    # generate some json for the snapshot graph
    def snapshot_graph_json(target, snapshots)
        data = snapshots[:avg][target]
        data = 10 if target == 'load' && snapshots[:avg]['load'] > 10
        total = snapshots[:scale][target]
        remaining = total - data

        graph_object = {
            :timepoints => [],
            :dataset =>
            [
                {
                    :name => target,
                    :values => [data],
                    :fill => data.to_f / total.to_f > 0.75 ? 'red' : 'blue',
                    :stroke => 'lightgray',
                    :strokeWidth => 1
                },
                {
                    :name => target + 'remaining',
                    :values => [remaining],
                    :fill => 'white',
                    :stroke => 'lightgray',
                    :strokeWidth => 1
                }
            ]
        }
        return ActiveSupport::JSON.encode(graph_object)
    end

    # generate some json for availability graph
    def availability_graph_json(title, total, available, used)
        color = 'blue'
        data_sets = []
        if (total > used)
            # 3/4 is the critical boundry for now
            color = 'red' if (used.to_f / total.to_f) > 0.75
            data_sets.push({ :name => title + '_used', :values => [used],
                             :fill => color, :stroke => 'lightgray', :strokeWidth => 1 },
                           { :name => title + '_available',
                             :values => [available], :fill => 'white',
                             :stroke => 'lightgray', :strokeWidth => 1})
        else
            data_sets.push({ :name => title + '_available', :values => [available],
                             :fill => 'white', :stroke => 'lightgray', :strokeWidth => 1 },
                           { :name => title + '_used',
                             :values => [used], :fill => 'red',
                             :stroke => 'lightgray', :strokeWidth => 1})
        end
        return ActiveSupport::JSON.encode({:timepoints => [], :dataset => data_sets})
    end

    def get_scaled_data(type, data)
      if (data[:avg][type] > data[:scale][type])
          data[:avg][type] = data[:scale][type]
      end
      # 180 is the maximum width we display for the bar graph in the ui
      data[:avg][type] * (180.0/data[:scale][type])
    end

    def get_percentage(type, data)
      if (data[:avg][type] > data[:scale][type])
          return 100
      end
      (data[:avg][type].to_f/data[:scale][type]) * 100
    end
end
