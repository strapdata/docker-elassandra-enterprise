#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -ex

#---- input params ----
# the base image to inherit from
BASE_IMAGE=${BASE_IMAGE:-elassandra:latest}

# The script need the strapack git repository where the zip package has been built
STRAPACK_DIR=${STRAPACK_DIR}
STRAPACK_URL=${STRAPACK_URL}
if [ -z "$STRAPACK_DIR" ] && [ -z "$STRAPACK_URL" ]; then
  echo "STRAPACK_DIR must be set to the elassandra repository directory (with debian package assembled inside)"
  echo "or STRAPACK_URL must point to an url or path containing a elassandra debian package."
  exit 1
fi

# optionally, the sha1 of the commit, if applicable
# this will be used to tag the image
STRAPACK_COMMIT=${STRAPACK_COMMIT:-""}

#---- output params ----
# If set, the images will be published to docker hub
DOCKER_PUBLISH=${DOCKER_PUBLISH:-false}

# Unless specified with a trailing slash, publish in the public strapdata docker hub
DOCKER_REGISTRY=${DOCKER_REGISTRY:-""}

# If set, the images will be tagged latest
DOCKER_LATEST=${DOCKER_LATEST:-false}

# set the docker hub repository name
REPO_NAME=${REPO_NAME:-"strapdata/elassandra-enterprise"}

# the target names of the images
DOCKER_IMAGE=${DOCKER_REGISTRY}${REPO_NAME}

# Options to add to docker build command
DOCKER_BUILD_OPTS=${DOCKER_BUILD_OPTS:-"--rm"}


wget_package() {
  local url=$1
  mkdir -p tmp-cache
  # download the deb package into the cache folder
  # the -N option ensure we do not download the file when we already have an up-to-date copy locally
  wget -N $url -P tmp-cache/
  PACKAGE_SRC=tmp-cache/$(basename $url)
}


if [ -n "$STRAPACK_DIR" ]; then
  # get the first elassandra deb in the distributions folder of the git repository
  PACKAGE_SRC=$(ls ${STRAPACK_DIR}/distribution/target/releases/strapdata-enterprise-*.zip | head -n1 | cut -d " " -f1)

elif [ -n "$STRAPACK_URL" ] && [[ $STRAPACK_URL = http* ]]; then
  # download the file from the web
  wget_package $STRAPACK_URL

else
  echo "error: unreachable... you may report the issue"
  exit 1
fi

# extract the elassandra version name
STRAPACK_VERSION=$(echo ${PACKAGE_SRC} | sed 's/.*strapdata-enterprise\-\(.*\).zip/\1/')
ELASSANDRA_TAG=$(echo ${BASE_IMAGE} | sed 's/.*:\(.*\)/\1/')

# setup the tmp-build directory
mkdir -p tmp-build
cp ${PACKAGE_SRC} tmp-build/

# build the image
echo "Building elassandra-enterprise docker image for $BASE_IMAGE with strapack $STRAPACK_VERSION"
docker build --build-arg STRAPACK_VERSION=${STRAPACK_VERSION} \
             --build-arg BASE_IMAGE=${BASE_IMAGE} \
             ${STRAPACK_COMMIT:+"--build-arg STRAPACK_COMMIT=${STRAPACK_COMMIT}"} \
             ${DOCKER_BUILD_OPTS} -f Dockerfile -t "$DOCKER_IMAGE:$ELASSANDRA_TAG" .

# cleanup
rm -rf tmp-build

publish() {
  if [ "$DOCKER_PUBLISH" = true ]; then
    echo "Publishing $1"
    docker push ${1}
  fi
}

# tag and publish image if DOCKER_PUBLISH=true
publish ${DOCKER_IMAGE}:${ELASSANDRA_TAG}

if [ "$DOCKER_LATEST" = "true" ]; then
  docker tag ${DOCKER_IMAGE}:${ELASSANDRA_TAG} ${DOCKER_IMAGE}:latest
  publish ${DOCKER_IMAGE}:latest
fi

if [ ! -z "$ELASSANDRA_COMMIT" ]; then
  docker tag ${DOCKER_IMAGE}:${ELASSANDRA_TAG} ${DOCKER_IMAGE}:${ELASSANDRA_COMMIT}
  publish ${DOCKER_IMAGE}:${ELASSANDRA_COMMIT}
fi
