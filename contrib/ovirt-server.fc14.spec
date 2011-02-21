%define app_root %{_datadir}/%{name}
%define acehome  %{_datadir}/ace
%define extra_release git

Summary: The oVirt Server Suite
Name: ovirt-server
Version: 1.9.3
Release: 0%{?dist}%{?extra_release}
# full source URL will be added with the next oVirt release. This is a pre-release
# code drop to make sure we get the package approved by f12 feature freeze.
Source0: server.tar.gz
#Entire source code is GPL except for vendor/plugins/will_paginate and
#vendor/plugins/betternestedset, which are MIT, and
#public/javascripts/jquery.*, which is both MIT and GPL, and
#src/flexchart/com/adobe/serialization/json/* which are BSD
License: GPLv2+ and MIT and BSD
Group: Applications/System
Requires: ruby >= 1.8.1
Requires: ruby(abi) = 1.8
Requires: rubygem(activerecord) >= 2.1.1-2
Requires: rubygem(activeldap) >= 0.10.0
Requires: rubygem(rails) >= 2.1.1
Requires: rubygem(mongrel) >= 1.0.1
Requires: rubygem(krb5-auth) >= 0.6
Requires: rubygem(cobbler) >= 0.1.2
%if 0%{?fedora} >= 11
Requires: rubygem(gettext_rails)
%else
Requires: rubygem(gettext)
%endif
Requires: ruby-flexmock
Requires: postgresql-server
Requires: ruby-postgres
Requires: xapian-bindings-ruby
Requires: xapian-core
Requires: pwgen
Requires: httpd >= 2.0
Requires: mod_auth_kerb
Requires: ruby-libvirt >= 0.0.2
Requires: rrdtool-ruby
Requires: iscsi-initiator-utils
Requires: cyrus-sasl-gssapi
Requires: qpid-cpp-server
Requires: qpid-cpp-client
Requires: qmf >= 0.5.829175-2
Requires: ruby-qmf
Requires(post):  /sbin/chkconfig
Requires(preun): /sbin/chkconfig
Requires(preun): /sbin/service
BuildRequires: ruby >= 1.8.1
BuildRequires: ruby-devel
BuildRequires: rubygem(gettext)
BuildRequires: rubygem(rake) >= 0.7
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
URL: http://ovirt.org/

%package installer
Summary: Installer modules for the oVirt Server Suite
Group: Applications/System
Requires: ruby(abi) = 1.8
Requires: ace
Requires: ace-postgres
Requires: rubygem(highline)
Requires: hal
Requires: %{name} = %{version}-%{release}

%description
The Server Suite for oVirt.

%description installer
The Installer for the ovirt server suite

%prep
%setup -q -n server

%build

%install
test "x%{buildroot}" != "x" && rm -rf %{buildroot}
mkdir %{buildroot}

%{__install} -d -m0755 %{buildroot}%{_bindir}
%{__install} -d -m0755 %{buildroot}%{_datadir}
%{__install} -d -m0755 %{buildroot}%{_sbindir}
%{__install} -d -m0755 %{buildroot}%{_initrddir}
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/sysconfig
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/%{name}
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/%{name}/db
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/logrotate.d
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/cron.d
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/lib/%{name}
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/log/%{name}
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/run/%{name}
%{__install} -d -m0755 %{buildroot}%{app_root}
%{__install} -d -m0755 %{buildroot}/%{acehome}

# Creating these files now to make sure the logfiles will be owned
# by ovirt:ovirt. This is a temporary workaround while we've still
# got root-owned daemon processes. Once we resolve that issue
# these files will no longer be added explicitly here.
touch %{buildroot}%{_localstatedir}/log/%{name}/mongrel.log
touch %{buildroot}%{_localstatedir}/log/%{name}/rails.log
touch %{buildroot}%{_localstatedir}/log/%{name}/taskomatic.log
touch %{buildroot}%{_localstatedir}/log/%{name}/db-omatic.log
%{__install} -p -m0644 conf/%{name}.crontab %{buildroot}%{_sysconfdir}/cron.d/%{name}
%{__install} -p -m0644 conf/%{name}.logrotate %{buildroot}%{_sysconfdir}/logrotate.d/%{name}

%{__install} -Dp -m0755 conf/ovirt-host-browser %{buildroot}%{_initrddir}
%{__install} -Dp -m0755 conf/ovirt-host-register %{buildroot}%{_initrddir}
%{__install} -Dp -m0755 conf/ovirt-db-omatic %{buildroot}%{_initrddir}
%{__install} -Dp -m0755 conf/ovirt-agent %{buildroot}%{_initrddir}
%{__install} -Dp -m0755 conf/ovirt-host-collect %{buildroot}%{_initrddir}
%{__install} -Dp -m0755 conf/ovirt-mongrel-rails %{buildroot}%{_initrddir}
%{__install} -Dp -m0644 conf/ovirt-mongrel-rails.sysconf %{buildroot}%{_sysconfdir}/sysconfig/ovirt-mongrel-rails
%{__install} -Dp -m0644 conf/ovirt-rails.sysconf %{buildroot}%{_sysconfdir}/sysconfig/ovirt-rails
%{__install} -Dp -m0644 conf/ovirt-vnc-proxy.sysconf %{buildroot}%{_sysconfdir}/sysconfig/ovirt-vnc-proxy
%{__install} -Dp -m0755 conf/ovirt-taskomatic %{buildroot}%{_initrddir}
%{__install} -Dp -m0755 conf/ovirt-vnc-proxy %{buildroot}%{_initrddir}

# copy over all of the src directory...
%{__cp} -a src/* %{buildroot}%{app_root}

# move Flash movie to the public folder
%{__install} -d -m0755 %{buildroot}%{app_root}/public/swfs
# not building Flash for now until we've got flex compiler in Fedora

# move configs to /etc, keeping symlinks for Rails
%{__mv} %{buildroot}%{app_root}/config/database.yml %{buildroot}%{_sysconfdir}/%{name}
%{__mv} %{buildroot}%{app_root}/config/ldap.yml %{buildroot}%{_sysconfdir}/%{name}
%{__mv} %{buildroot}%{app_root}/config/cobbler.yml %{buildroot}%{_sysconfdir}/%{name}
%{__mv} %{buildroot}%{app_root}/config/environments/development.rb %{buildroot}%{_sysconfdir}/%{name}
%{__mv} %{buildroot}%{app_root}/config/environments/production.rb %{buildroot}%{_sysconfdir}/%{name}
%{__mv} %{buildroot}%{app_root}/config/environments/test.rb %{buildroot}%{_sysconfdir}/%{name}
%{__ln_s} %{_sysconfdir}/%{name}/database.yml %{buildroot}%{app_root}/config
%{__ln_s} %{_sysconfdir}/%{name}/ldap.yml %{buildroot}%{app_root}/config
%{__ln_s} %{_sysconfdir}/%{name}/cobbler.yml %{buildroot}%{app_root}/config
%{__ln_s} %{_sysconfdir}/%{name}/development.rb %{buildroot}%{app_root}/config/environments
%{__ln_s} %{_sysconfdir}/%{name}/production.rb %{buildroot}%{app_root}/config/environments
%{__ln_s} %{_sysconfdir}/%{name}/test.rb %{buildroot}%{app_root}/config/environments

# remove the files not needed for the installation
%{__rm} -f %{buildroot}%{app_root}/task-omatic/.gitignore
%{__rm} -f %{buildroot}%{app_root}/vendor/plugins/will_paginate/.gitignore
%{__rm} -f %{buildroot}%{app_root}/vendor/plugins/will_paginate/.manifest
%{__rm} -f %{buildroot}%{app_root}/vendor/plugins/acts_as_xapian/.gitignore

%{__cp} -a scripts/ovirt-add-host %{buildroot}%{_bindir}
%{__cp} -a scripts/ovirt-vm2node %{buildroot}%{_bindir}
%{__cp} -a scripts/ovirt-reindex-search %{buildroot}%{_sbindir}
%{__cp} -a scripts/ovirt-update-search %{buildroot}%{_sbindir}
%{__cp} -a scripts/ovirt_ctl %{buildroot}%{_sbindir}
%{__rm} -rf %{buildroot}%{app_root}/tmp
%{__mkdir} %{buildroot}%{_localstatedir}/lib/%{name}/tmp
%{__ln_s} %{_localstatedir}/lib/%{name}/tmp %{buildroot}%{app_root}/tmp

# Set up the installer
%{__cp} -pr installer/modules %{buildroot}/%{acehome}
%{__cp} -pr installer/appliances %{buildroot}/%{acehome}
%{__cp} -pr installer/bin/ovirt-installer %{buildroot}%{_sbindir}

# setup the anyterm config
%{__mkdir} -p %{buildroot}%{_datadir}/ovirt-anyterm/
for f in anyterm/*.{html,css,js,png,gif}; do
   %{__install} -m644 "$f" %{buildroot}%{_datadir}/ovirt-anyterm/
done

%clean
rm -rf %{buildroot}

%pre
getent group ovirt >/dev/null || /usr/sbin/groupadd -g 108 -r ovirt 2>/dev/null || :
getent passwd ovirt >/dev/null || \
    /usr/sbin/useradd -u 108 -g ovirt -c "oVirt" \
    -s /sbin/nologin -r -d /var/ovirt ovirt 2> /dev/null || :

%post
# script
%define daemon_chkconfig_post(d:) \
/sbin/chkconfig --list %{-d*} >& /dev/null \
LISTRET=$? \
/sbin/chkconfig --add %{-d*} \
if [ $LISTRET -ne 0 ]; then \
    /sbin/chkconfig %{-d*} on \
fi \
%{nil}

# if this is the initial RPM install, then we want to turn the new services
# on; otherwise, we respect the choices the administrator already has made.
# check this by seeing if each daemon is already installed
%daemon_chkconfig_post -d ovirt-host-browser
%daemon_chkconfig_post -d ovirt-host-register
%daemon_chkconfig_post -d ovirt-db-omatic
%daemon_chkconfig_post -d ovirt-agent
%daemon_chkconfig_post -d ovirt-host-collect
%daemon_chkconfig_post -d ovirt-mongrel-rails
%daemon_chkconfig_post -d ovirt-taskomatic
%daemon_chkconfig_post -d ovirt-vnc-proxy

%preun
if [ "$1" = 0 ] ; then
  /sbin/service ovirt-host-browser stop > /dev/null 2>&1
  /sbin/service ovirt-host-register stop > /dev/null 2>&1
  /sbin/service ovirt-db-omatic stop > /dev/null 2>&1
  /sbin/service ovirt-agent stop > /dev/null 2>&1
  /sbin/service ovirt-host-collect stop > /dev/null 2>&1
  /sbin/service ovirt-mongrel-rails stop > /dev/null 2>&1
  /sbin/service ovirt-taskomatic stop > /dev/null 2>&1
  /sbin/service ovirt-vnc-proxy stop > /dev/null 2>&1
  /sbin/chkconfig --del ovirt-host-browser
  /sbin/chkconfig --del ovirt-host-register
  /sbin/chkconfig --del ovirt-db-omatic
  /sbin/chkconfig --del ovirt-agent
  /sbin/chkconfig --del ovirt-host-collect
  /sbin/chkconfig --del ovirt-mongrel-rails
  /sbin/chkconfig --del ovirt-taskomatic
  /sbin/chkconfig --del ovirt-vnc-proxy
fi

%files
%defattr(-,root,root,0755)
%{_sbindir}/ovirt-reindex-search
%{_sbindir}/ovirt-update-search
%{_bindir}/ovirt-add-host
%{_bindir}/ovirt-vm2node
%{_sbindir}/ovirt_ctl
%{_initrddir}/ovirt-host-browser
%{_initrddir}/ovirt-host-register
%{_initrddir}/ovirt-db-omatic
%{_initrddir}/ovirt-agent
%{_initrddir}/ovirt-host-collect
%{_initrddir}/ovirt-mongrel-rails
%{_initrddir}/ovirt-taskomatic
%{_initrddir}/ovirt-vnc-proxy
%config(noreplace) %{_sysconfdir}/cron.d/%{name}
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}
%config(noreplace) %{_sysconfdir}/sysconfig/ovirt-mongrel-rails
%config(noreplace) %{_sysconfdir}/sysconfig/ovirt-rails
%config(noreplace) %{_sysconfdir}/sysconfig/ovirt-vnc-proxy
%doc README AUTHORS COPYING
%attr(-, ovirt, ovirt) %{_localstatedir}/lib/%{name}
%attr(-, ovirt, ovirt) %{_localstatedir}/run/%{name}
%attr(-, ovirt, ovirt) %{_localstatedir}/log/%{name}
%{app_root}
%dir %{_sysconfdir}/%{name}
%dir %{_sysconfdir}/%{name}/db
%config(noreplace) %{_sysconfdir}/%{name}/database.yml
%config(noreplace) %{_sysconfdir}/%{name}/ldap.yml
%config(noreplace) %{_sysconfdir}/%{name}/cobbler.yml
%config(noreplace) %{_sysconfdir}/%{name}/development.rb
%config(noreplace) %{_sysconfdir}/%{name}/production.rb
%config(noreplace) %{_sysconfdir}/%{name}/test.rb
%{_datadir}/ovirt-anyterm

%files installer
%defattr(-,root,root,0755)
%{_sbindir}/ovirt-installer
%{acehome}
%doc README AUTHORS COPYING


%changelog
* Tue May  4 2010 Darryl L. Pierce <dpierce@redhat.com> - 1.9.2-1
- Release 1.9.2 of the package.

* Tue Apr  6 2010 Darryl L. Pierce <dpierce@redhat.com> - 1.9.1-1
- Release 1.9.1 of the package.

* Fri Jul 17 2009 Scott Seago <sseago@redhat.com> - 0.100-1
- rpmlint fixes for Fedora 12 inclusion

* Thu May 29 2008 Alan Pevec <apevec@redhat.com> - 0.0.5-0
- use rubygem-krb5-auth

* Fri Nov  2 2007  <sseago@redhat.com> - 0.0.1-1
- Initial build.

