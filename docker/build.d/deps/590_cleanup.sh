#!/bin/sh

skip_cleanup && return 0

sectionText "Removing build depedencies"
apk del .build_deps || true

sectionText "Cleaning up /tmp folder"
rm -rf /tmp/*

sectionText "Removing apk package index files"
find /var/cache/apk  -type f -exec rm {} \;

if ! is_true $KEEP_DEVEL_TOOLS; then
  REMOVEABLE_LIST=`find $WORKDIR/vendor -type d -name 'node_modules'`
  REMOVEABLE_LIST="/root/.npm $WORKDIR/node_modules $WORKDIR/package.json $WORKDIR/package.lock /root/.composer /usr/bin/composer.phar $REMOVEABLE_LIST"
  sectionText "Removing node/php artifacts"
  for removeable in $REMOVEABLE_LIST; do
  if [ -e $removeable ]; then
    sectionText "Removing $removeable"
    rm -rf $removeable
  fi
  done
fi 

