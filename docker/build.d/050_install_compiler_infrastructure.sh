#!/bin/sh

# use ccache to improve compile times
apk add --virtual .base_build_deps ccache autoconf file g++ gcc libc-dev make pkgconf