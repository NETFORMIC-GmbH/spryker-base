#!/bin/sh

KEEP_DEVEL_TOOLS=false
SKIP_CLEANUP=false

# log destinations
BUILD_LOG=/data/logs/build.log

# Packages installed temporary during build time (base and deps layer)
COMMON_BUILD_DEPENDENCIES="ccache autoconf file g++ gcc libc-dev make pkgconf bash"
BUILD_DEPENDENCIES=""

# Base dependencies to be installed
COMMON_BASE_DEPENDENCIES="perl graphviz"
BASE_DEPENDENCIES=""

#  NodeJS defaults
NODEJS_VERSION="6" # nodejs major 6 or 7 are supported
NPM=npm            # npm or yarn are supported

#  PHP defaults
# pecl extensions
PHP_EXTENSION_IMAGICK="3.4.3"
PHP_EXTENSION_REDIS="3.1.2"

CONSOLE="exec_console"

# a list of common PHP extensions required to run a spryker shop
COMMON_PHP_EXTENSIONS="bcmath bz2 gd gmp intl mcrypt redis opcache"
PHP_EXTENSIONS=""

# crond is the only allowed cronjob handler until we got a solution for jenkins too
# crond might be dropped then, so please don't rely on "crond" in your shop flavour!
CRONJOB_HANDLER="crond"
