#!/usr/bin/ruby
#
# vnc-proxy.rb
# ovirt vnc proxy server, relays ovirt encoded
#   vnc requests to correct node
# Copyright (C) 2009 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
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

$: << File.join(File.dirname(__FILE__), "../dutils")

require 'dutils'
require 'daemons'
include Daemonize

###########

DEFAULT_VNC_PROXY_PORT = 5900
VM_NAME_MAX_LEN   = 250
VNC_DATA_MAX_LEN = 800000

###########

# clone of the taskomatic / dbomatic logger;
# TODO move all of these seperate implementations into a single dutils module
class Logger
  def format_message(severity, timestamp, progname, msg)
    "#{severity} #{timestamp} (#{$$}) #{msg}\n"
  end
end

$logfile = '/var/log/ovirt-server/vnc-proxy.log'

###########


class VncProxy

    # initialize vnc proxy
    def initialize()
        do_daemon = true
        port = DEFAULT_VNC_PROXY_PORT

        opts = OptionParser.new do |opts|
            opts.on("-h", "--help", "Print help message") do
                puts opts
                exit
            end
            opts.on("-n", "--nodaemon", "Run interactively (useful for debugging)") do |n|
                do_daemon = false
            end
            opts.on("-p", "--port", "Port to listen on") do |n|
                port = n.to_i
            end
        end
        begin
            opts.parse!(ARGV)
        rescue OptionParser::InvalidOption
            puts opts
            exit
        end

        if do_daemon
            # same issues as w/ dbomatic / taskomatic
            pwd = Dir.pwd
            daemonize
            Dir.chdir(pwd)
            @logger = Logger.new($logfile)
        else
            @logger = Logger.new(STDERR)
        end

        begin
          @server = TCPServer.open(port)
        rescue Exception => ex
           @logger.error "Error in vnc-proxy: #{ex}"
           @logger.error ex.backtrace

           # reraise ex, if we can't bind
           # to port server should die
           raise ex
        end

        @logger.info "vnc-proxy started."
     end

     # run vnc proxy
     def run
       continue = true
       while(continue) do
        begin
         Thread.start(@server.accept) do |client|
          begin
             @logger.info "client accepted"

             # first msg will be the vm description
             vm_description = client.recv(VM_NAME_MAX_LEN).to_s
             @logger.info "vm received: " + vm_description + ";"

             # lookup vm
             vm = Vm.find(:first, :conditions => [ "description = ?", vm_description ])
             if vm && vm.state == "running"
               # connect to node
               @logger.info "connecting to node " + vm.host.hostname + ":" + vm.vnc_port.to_s
               node_socket = TCPSocket.open(vm.host.hostname, vm.vnc_port)

               # begin new thread to process server->client messages
               Thread.start do
                 @logger.debug "listening for server->client data"
                 while(true)do
                   node_data = node_socket.recv VNC_DATA_MAX_LEN
                   break if node_data.size <= 0
                   client.write node_data
                 end
               end

               # process client -> server messages
               @logger.debug "listening for client->server data"
               while(true) do
                 client_data = client.recv VNC_DATA_MAX_LEN
                 break if client_data.size <= 0
                 node_socket.write client_data
               end

               node_socket.close
               @logger.info "node connection terminated"
             end
          rescue Exception => ex
            @logger.error "Error w/ vnc-proxy client (non-fatal) #{ex}"
          end

          client.close
          @logger.info "client connection terminated"
         end

        rescue Exception => ex
          continue = false
          @logger.error "terminating vnc proxy server #{ex}"
        end
       end

       @server.close
       @logger.info "server terminated"
     end
end

def main()
   vncproxy = VncProxy.new
   vncproxy.run
end

main()
