#!/usr/bin/ruby -Wall
#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>
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
$: << File.join(File.dirname(__FILE__), "../")

require 'rubygems'
require 'dutils'

require 'socket'
require 'krb5_auth'
include Krb5Auth
require 'daemons'
include Daemonize

include Socket::Constants

$logfile = '/var/log/ovirt-server/host-browser.log'

# +HostBrowser+ provides kerberos related services to a managed node.
class HostBrowser
    attr_accessor :logfile
    attr_accessor :keytab_dir
    attr_accessor :keytab_filename

    def initialize(session)
        @session = session
        @keytab_dir = '/usr/share/ipa/html/'
        set_peeraddr @session.peeraddr[3]
    end

    def set_peeraddr(peeraddr)
      @peeraddr = peeraddr
    end

    def prefix(session)
      "#{Time.now.strftime('%b %d %H:%M:%S')} #{@peeraddr} "
    end

    # Ensures the conversation starts properly.
    #
    def begin_conversation
        puts "#{prefix(@session)} Begin conversation" unless defined?(TESTING)
        @session.write("HELLO?\n")

        response = @session.readline.chomp
        raise Exception.new("received #{response}, expected HELLO!") unless response == "HELLO!"
    end

    # Retrieves the mode request from the remote system.
    #
    def get_mode
        puts "#{prefix(@session)} Determining the runtime mode." unless defined?(TESTING)
        @session.write("MODE?\n")
        response = @session.readline.chomp
        puts "#{prefix(@session)} MODE=#{response}" unless defined?(TESTING)

        response
    end

    # Creates a keytab if one is needed, returning the filename.
    #
    def create_keytab(hostname, ipaddress, krb5_arg = nil)
        krb5 = krb5_arg || Krb5.new

        default_realm = krb5.get_default_realm
        qpidd_princ = 'qpidd/' + hostname + '@' + default_realm
        libvirt_princ = 'libvirt/' + hostname + '@' + default_realm
        outfile = ipaddress + '-libvirt.tab'
        @keytab_filename = @keytab_dir + outfile

        # TODO need a way to test this portion
        unless (defined? TESTING) || File.exists?(@keytab_filename)
            # TODO replace with Kr5Auth when it supports admin actions
            puts "Writing keytab file: #{@keytab_filename}" unless defined?(TESTING)
            kadmin_local('addprinc -randkey ' + libvirt_princ)
            kadmin_local('ktadd -k ' + @keytab_filename + ' ' + libvirt_princ)
            kadmin_local('addprinc -randkey ' + qpidd_princ)
            kadmin_local('ktadd -k ' + @keytab_filename + ' ' + qpidd_princ)

            File.chmod(0644,@keytab_filename)
        end

        hostname = `hostname -f`.chomp

        @session.write("KTAB http://#{hostname}/ipa/config/#{outfile}\n")

        response = @session.readline.chomp

        raise Exception.new("ERRINFO! No keytab acknowledgement") unless response == "ACK"
    end

    # Ends the conversation, notifying the user of the key version number.
    #
    def end_conversation
        puts "#{prefix(@session)} Ending conversation" unless defined?(TESTING)

        @session.write("BYE\n");
    end

    private

    # Executes an external program to support the keytab function.
    #
    def kadmin_local(command)
        system("/usr/kerberos/sbin/kadmin.local -q '" + command + "'")
    end
end

def entry_point(server)
    while(session = server.accept)
        child = fork do
            remote = session.peeraddr[2]

            puts "Connected to #{remote}" unless defined?(TESTING)

            begin
                browser = HostBrowser.new(session)

                browser.begin_conversation
                case browser.get_mode
                    when "AWAKEN": browser.create_keytab(remote,session.peeraddr[3])
                end

                browser.end_conversation
            rescue Exception => error
                session.write("ERROR #{error.message}\n")
                puts "ERROR #{error.message}" unless defined?(TESTING)
            end

            puts "Disconnected from #{remote}" unless defined?(TESTING)
        end

        Process.detach(child)
    end
end

unless defined?(TESTING)
    # The main entry point.
    #
    unless ARGV[0] == "-n"
        daemonize
        # redirect output to the log
        STDOUT.reopen $logfile, 'a'
        STDERR.reopen STDOUT
    end

    server = TCPServer.new("",12120)
    entry_point(server)
end
