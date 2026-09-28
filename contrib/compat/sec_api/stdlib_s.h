/*
 * Compatibility shim for building openconnect with mingw-w64 >= 14.
 *
 * openconnect's compat.c includes <sec_api/stdlib_s.h> to get errno_t, but
 * mingw-w64 no longer ships the sec_api headers. This header is put on the
 * include path by contrib/build_deps_mingw@msys2.sh and provides just that
 * type; getenv_s() and _putenv_s() are declared by compat.c itself.
 */

#pragma once

#include <stdlib.h>

#ifndef _ERRNO_T_DEFINED
#define _ERRNO_T_DEFINED
typedef int errno_t;
#endif
