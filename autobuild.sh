#!/bin/sh
#oVirt server autobuild script
#
# Copyright (C) 2008 Red Hat, Inc.
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

echo "Running oVirt server Autobuild"

set -e
set -v

test -f Makefile && make -k distclean || :

############# build the server rpm

# put rails in development mode
cp conf/ovirt-rails.sysconf conf/ovirt-rails.sysconf.orig
echo "RAILS_ENV=development" >> conf/ovirt-rails.sysconf

# build server & installer rpms
./autogen.sh --prefix=$AUTOBUILD_INSTALL_ROOT
make dist

if [ -f /usr/bin/rpmbuild ]; then
  if [ -n "$AUTOBUILD_COUNTER" ]; then
    EXTRA_RELEASE=".auto$AUTOBUILD_COUNTER"
  else
    NOW=`date +"%s"`
    EXTRA_RELEASE=".$USER$NOW"
  fi

  rpmbuild --nodeps --define "extra_release $EXTRA_RELEASE" -ta --clean *.tar.gz
fi

# restore to checkout
mv conf/ovirt-rails.sysconf.orig conf/ovirt-rails.sysconf

# create the repo (need to be done here so the latest
#  version is accessible to the install process)
createrepo $AUTOBUILD_PACKAGE_ROOT/rpm/RPMS

############## setup new vm to test installer

# setup parameters to ssh to vm
SSHKEY=~/.ssh/id_autobuild
remote_target="root@192.168.122.190" # should be an address on default libvirt network
ssh_cmd="ssh -i $SSHKEY -o StrictHostKeyChecking=no \
             -o UserKnownHostsFile=/dev/null $remote_target"
scp_cmd="scp -i $SSHKEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# generate new ssh key if not found
if [ ! -r $SSHKEY ]; then
  mkdir -p $(dirname "$SSHKEY")
  ssh-keygen -q -t rsa -N "" -f $SSHKEY
fi

# copy the key and installer answers to the kickstart
cp ovirt-server-test.ks ovirt-server-test.ks.orig
cat >> ovirt-server-test.ks << KS
%post
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat > /root/.ssh/authorized_keys << \EOF
$(ssh-keygen -y -f $SSHKEY)
EOF
chmod 600 /root/.ssh/authorized_keys

cat > /root/ovirt-installer-answers << \EOF
$(cat ovirt-installer-test-answers)
EOF

%end
KS

# remove old server vm
test ! -f ovirt-server-test.tar || rm -f ovirt-server-test.tar
test ! -d test-vm || rm -rf test-vm
sudo virsh destroy ovirt-server-test || true
sudo virsh undefine ovirt-server-test || true

# create new vm for server, configuring via kickstart, boot it
sudo appliance-creator --config ovirt-server-test.ks --name ovirt-server-test \
                       -f qcow2 -p tar -d -v

# restore original kickstart
mv ovirt-server-test.ks.orig ovirt-server-test.ks

# define the libvirt vm, boot it
mkdir -p test-vm
tar -xSvf ovirt-server-test.tar -C test-vm
sudo virt-image test-vm/ovirt-server-test/ovirt-server-test.xml
sudo virsh define /etc/libvirt/qemu/ovirt-server-test.xml

################### test server vm

# wait till ovirt-appliance is started
for i in $(seq 1 60); do
  $ssh_cmd exit && break
  sleep 10
done

# run installer on server vm, answering preconfigured questions
$ssh_cmd "ovirt-installer < /root/ovirt-installer-answers"
$ssh_cmd "ace -d install ovirt" || true  # FIXME when "installer always returns failed"
                                         #  bug is fixed, remove this "|| true"

# run tests on newly installed server
$ssh_cmd "cd /usr/share/ovirt-server && rake db:migrate && rake test"
