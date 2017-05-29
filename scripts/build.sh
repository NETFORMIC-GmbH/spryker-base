#!/bin/bash

set -e -o pipefail

ROOT="$(cd `dirname $0` && cd .. && pwd )"
IMAGE="claranet/spryker-base"
VERSION="$(cat $ROOT/VERSION)"

[[ -n "$BUILD_NUMBER" ]] && VERSION="$VERSION.$BUILD_NUMBER"

echo "[INFO] Building image $IMAGE:$VERSION"
pushd $ROOT
docker build -f Dockerfile --no-cache --force-rm --tag $IMAGE:$VERSION .
docker tag $IMAGE:$VERSION $IMAGE:latest
popd
