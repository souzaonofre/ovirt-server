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

make tar

if [ -f /usr/bin/rpmbuild ]; then
  if [ -n "$AUTOBUILD_COUNTER" ]; then
    EXTRA_RELEASE=".auto$AUTOBUILD_COUNTER"
  else
    NOW=`date +"%s"`
    EXTRA_RELEASE=".$USER$NOW"
  fi
  # manually copy files over until we have an autotools
  #  generated tarball to base rpmbuild on
  cp version $AUTOBUILD_PACKAGE_ROOT/rpm/SOURCES/
  cp rpm-build/ovirt-server-0.92.tar.gz $AUTOBUILD_PACKAGE_ROOT/rpm/SOURCES/

  rpmbuild --nodeps --define "extra_release $EXTRA_RELEASE" -ba --clean ovirt-server.spec
fi
