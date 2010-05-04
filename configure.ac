AC_INIT([ovirt-server], [1.9.3], [ovirt-devel@redhat.com])
AM_INIT_AUTOMAKE([-Wall -Werror foreign -Wno-portability tar-pax])
AC_PROG_CC
AC_CONFIG_HEADERS([config.h])

# If using gcc and default CFLAGS, enable some warnings.
test x"$ac_ct_CC:$CFLAGS" = 'xgcc:-g -O2' \
  && CFLAGS="$CFLAGS -Wshadow -Wall -Werror"

AC_CHECK_PROGS(RUBY, ruby rake gem)

if test x"$RUBY" = x ; then
   AC_MSG_ERROR([Missing ruby development programs.])
fi

AC_CHECK_LIB(ruby, main, , AC_MSG_ERROR([Cannot find development libraries.]))

AC_CONFIG_FILES([Makefile ovirt-server.spec])
AC_OUTPUT
