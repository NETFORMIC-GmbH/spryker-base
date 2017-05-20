#!/bin/sh

if [ -n "$NETRC" ]; then
    sectionText "Injecting temporary credentials via .netrc ..."
    echo -e "$NETRC" >> $HOME/.netrc
fi

sectionText "Diverting git transport from SSH to HTTPS ..."
git config --global "url.https://".insteadof "git://git@"

composer.phar config --global github-protocols https
