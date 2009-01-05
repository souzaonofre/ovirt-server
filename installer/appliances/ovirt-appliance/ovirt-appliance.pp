# Sample file as if the user had run the ovirt-installer program
import 'ovirt'
import 'firewall'

firewall::setup{'setup': status => 'disabled'}

# dns configuration
$mgmt_ipaddr = '192.168.222.211'
$prov_ipaddr = ''
$ovirt_host = 'management.priv.ovirt.org'
$ipa_host = 'management.priv.ovirt.org'

dns::bundled{setup: mgmt_ipaddr=> $mgmt_ipaddr, prov_ipaddr=> $prov_ipaddr, mgmt_dev => 'eth0', prov_dev => 'eth1'}

# dhcp configuration
$dhcp_interface = 'eth1'
$dhcp_network = '192.168.50'
$dhcp_start = '3'
$dhcp_stop = '10'
$dhcp_domain = 'priv.ovirt.org'
$ntp_server = '192.168.222.211'

$prov_dns_server = ''
$prov_network_gateway = '192.168.50.1'
# cobbler configuration
$cobbler_hostname = 'localhost'
$cobbler_user_name = 'cobbler'
$cobbler_user_password = 'cobbler'

# postgres configuration
$db_username = 'ovirt'
$db_password = 'cobbler'

# FreeIPA configuration
$realm_name = 'priv.ovirt.org'
$freeipa_password = 'password'
$ldap_dn = 'cn=ipaConfig,cn=etc,dc=priv,dc=ovirt,dc=org'

include cobbler::bundled
include dhcp::bundled
include tftp::bundled
include postgres::bundled
include freeipa::bundled
include ovirt::setup
