# Sample file as if the user had run the ovirt-installer program
import 'ovirt'
import 'firewall'

firewall::setup{'setup': status => 'enabled'}
firewall_rule{"ssh": destination_port => "22"}

# dns configuration
$guest_ipaddr = '192.168.50.2'
$admin_ipaddr = '192.168.50.2'
$ovirt_host = 'management.priv.ovirt.org'
$ipa_host = 'management.priv.ovirt.org'

dns::bundled{setup: guest_ipaddr=> $guest_ipaddr, admin_ipaddr=> $admin_ipaddr, guest_dev => 'eth0', admin_dev => 'eth0'}

# dhcp configuration
$dhcp_interface = 'eth0'
$dhcp_network = '192.168.50'
$dhcp_start = '3'
$dhcp_stop = '50'
$dhcp_domain = 'priv.ovirt.org'
$ntp_server =  $guest_ipaddr

$admin_dns_server = '192.168.50.2'
$admin_network_gateway = '192.168.50.1'
# cobbler configuration
$cobbler_hostname = 'localhost'
$cobbler_user_name = 'cobbler'
$cobbler_user_password = 'cobbler'

# postgres configuration
$db_username = 'ovirt'
$db_password = 'cobbler'

# FreeIPA configuration
$realm_name = 'priv.ovirt.org'
$freeipa_password = 'ovirt'
$ldap_dn = 'cn=ipaConfig,cn=etc,dc=priv,dc=ovirt,dc=org'
$short_ldap_dn = 'dc=priv,dc=ovirt,dc=org'

include cobbler::bundled
include dhcp::bundled
include tftp::bundled
include postgres::bundled
include freeipa::bundled
include ovirt::setup
include appliance::bundled
