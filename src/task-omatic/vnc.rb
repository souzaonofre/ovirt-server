# Copyright (C) 2008 Red Hat, Inc.
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

# provides static 'forward' and 'close' methods to forward a specified vm's vnc connections
class VmVnc

  private

    # TODO no ruby/libiptc wrapper exists, when
    # it does replace iptables command w/ calls to it
    IPTABLES_CMD='/sbin/iptables '

    VNC_DEBUG = false

    # FIXME can this be retreived in any way
    # since machine will have both external
    # and internal network interface
    LOCAL_IP = '192.168.50.2'

    def self.debug(msg)
      puts "\n" + msg + "\n" if VNC_DEBUG
    end

    def self.find_host_ip(hostname)
      # FIXME
      addrinfo = Socket::getaddrinfo(hostname, nil)
      unless addrinfo.size > 0
        raise "Could not retreive address for " + hostname
      end
      result = addrinfo[0][3] # return ip address of first entry
      debug( "vm host hostname  resolved to " + result.to_s )
      return result
    end

    def self.port_open?(port)
      cmd=IPTABLES_CMD + ' -t nat -nL '
      debug("vncPortOpen? iptables command: " + cmd)

      `#{cmd}`.each_line do |l|
          return true if l =~ /.*#{port}.*/
      end
      return false
    end

    def self.allocate_forward_vnc_port(vm)
       Vm.transaction do
         ActiveRecord::Base.connection.execute('LOCK TABLE vms')
         vm.forward_vnc_port = Vm.available_forward_vnc_port
         debug("Allocating forward vnc port " + vm.forward_vnc_port.to_s)
         vm.save!
       end
    end

    def self.deallocate_forward_vnc_port(vm)
       debug("Deallocating forward vnc port " + vm.forward_vnc_port.to_s)
       vm.forward_vnc_port = nil
       vm.save!
    end

    def self.get_forward_rules(vm)
      ip = find_host_ip(vm.host.hostname)
      return " -d " + ip + " -p tcp --dport " + vm.vnc_port.to_s + " -j ACCEPT",
             " -s " + ip + " -p tcp --sport " + vm.vnc_port.to_s + " -j ACCEPT"
    end

    def self.get_nat_rules(vm)
      ip = find_host_ip(vm.host.hostname)

      return " -p tcp --dport " + vm.forward_vnc_port.to_s + " -j DNAT --to " + ip + ":" + vm.vnc_port.to_s,
             " -d " + ip + " -p tcp --dport " + vm.vnc_port.to_s + " -j SNAT --to " + LOCAL_IP
    end

    def self.run_command(cmd)
      debug("Running command " + cmd)
      status = system(cmd)
      raise 'Command terminated with error code ' + $?.to_s unless status
    end

  public

    def self.forward(vm)
       return unless vm.forward_vnc

       allocate_forward_vnc_port(vm)
       if port_open?(vm.forward_vnc_port)
         deallocate_forward_vnc_port(vm)
         raise "Port already open " + vm.forward_vnc_port.to_s
       end

       forward_rule1, forward_rule2 = get_forward_rules(vm)
       forward_rule1 = IPTABLES_CMD + " -A FORWARD " + forward_rule1
       forward_rule2 = IPTABLES_CMD + " -A FORWARD " + forward_rule2

       prerouting_rule, postrouting_rule = get_nat_rules(vm)
       prerouting_rule = IPTABLES_CMD + " -t nat -A PREROUTING " + prerouting_rule
       postrouting_rule = IPTABLES_CMD + " -t nat -A POSTROUTING " + postrouting_rule

       debug(" open\n forward rule 1: "     + forward_rule1 +
              "\n forward_rule 2: "   + forward_rule2 +
              "\n prerouting rule: "  + prerouting_rule +
              "\n postrouting rule: " + postrouting_rule)


       File::open("/proc/sys/net/ipv4/ip_forward", "w") { |f| f.puts "1" }
       run_command(forward_rule1)
       run_command(forward_rule2)
       run_command(prerouting_rule)
       run_command(postrouting_rule)
    end

    def self.close(vm)
       return unless vm.forward_vnc

       unless port_open?(vm.forward_vnc_port)
         raise "Port not open " + vm.forward_vnc_port.to_s
       end

       forward_rule1, forward_rule2 = get_forward_rules(vm)
       forward_rule1 = IPTABLES_CMD + " -D FORWARD " + forward_rule1
       forward_rule2 = IPTABLES_CMD + " -D FORWARD " + forward_rule2

       prerouting_rule, postrouting_rule = get_nat_rules(vm)
       prerouting_rule = IPTABLES_CMD + " -t nat -D PREROUTING " + prerouting_rule
       postrouting_rule = IPTABLES_CMD + " -t nat -D POSTROUTING " + postrouting_rule

       debug(" close\n forward rule 1: "     + forward_rule1 +
              "\n forward_rule 2: "   + forward_rule2 +
              "\n prerouting rule: "  + prerouting_rule +
              "\n postrouting rule: " + postrouting_rule)

       run_command(forward_rule1)
       run_command(forward_rule2)
       run_command(prerouting_rule)
       run_command(postrouting_rule)


       deallocate_forward_vnc_port(vm)
    end
end
