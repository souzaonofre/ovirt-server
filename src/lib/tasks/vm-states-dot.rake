# -*- ruby -*-
require 'permission'
require 'task'
require 'vm'
require 'vm_task'

desc "Generate a dot file for VM state transitions (pass output file in\nvariable 'output')"
task "vm:states:dot" do
    out = $stdout
    out = File::open(ENV['output'], 'w') if ENV['output']

    # Classify states
    states = {}
    [:start, :running, :success, :failure].each do |tag|
        VmTask::ACTIONS.values.each { |a|
            states[a[tag]] ||= []
            states[a[tag]] << tag
        }
    end

    out.puts "digraph \"VM Task Transitions\" {"
    states.each do |state, tags|
        out.print "  #{state} ["
        if tags == [:running]
            out.print("shape=box color=\"#666666\" fontcolor=\"#666666\"")
        end
        out.puts "];"
    end
    VmTask::ACTIONS.values.each do |a|
        out.puts "#{a[:start]} -> #{a[:running]} [ label = \"#{a[:label]}\" ];"
        out.puts "#{a[:running]} -> #{a[:success]} [ color = green ];"
        out.puts "#{a[:running]} -> #{a[:failure]} [ color= red ];"
    end
    out.puts '":running" [shape=box color="#666666" fontcolor="#666666"];'
    out.puts '":start" -> ":running" [ label = "Action" ];'
    out.puts '":running" -> ":success" [ color = green ];'
    out.puts '":running" -> ":failure" [ color= red ];'
    out.puts "}"
    out.close
end
