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
BASE_IMAGE=${BASE_IMAGE:-strapdata/elassandra:latest}

# if true, remove the image to re-download it.
FORCE_PULL=${FORCE_PULL:-false}

# pull the image if not present, or if FORCE_PULL=true
if [ "$FORCE_PULL" = true ] || ! docker inspect --type=image $BASE_IMAGE > /dev/null; then
  docker rmi ${BASE_IMAGE} || true
  docker pull ${BASE_IMAGE}
fi

get_image_env() {
  local name=$1
  local image=${2:-${BASE_IMAGE}}
  local val=$(docker inspect -f  \
    '{{range $index, $value := .Config.Env}}{{println $value}}{{end}}' \
    $image | grep $name)
  echo ${val#"$name="}
}

# the elassandra version.
# if not set, it is inferred from the docker image env
ELASSANDRA_VERSION=${ELASSANDRA_VERSION:-$(get_image_env ELASSANDRA_VERSION)}
if [ -z $ELASSANDRA_VERSION ]; then
  echo "can't infer the elassandra version, missing env ELASSANDRA_VERSION" >&2
  exit 1
fi

# The script need the strapack git repository where the zip package has been built
PLUGIN_DIR=${PLUGIN_DIR}
PLUGIN_LOCATION=${PLUGIN_LOCATION}
if [ -z "$PLUGIN_DIR" ] && [ -z "$PLUGIN_LOCATION" ]; then
  echo "PLUGIN_DIR must be set to the elassandra repository directory (with debian package assembled inside)"
  echo "or PLUGIN_LOCATION must point to an url or path containing the enterprise plugin."
  exit 1
fi

# optionally, the sha1 of the strapack commit, if applicable
# this will be used to tag the image.
# If PLUGIN_DIR is set, it will be inferred from the git repository
PLUGIN_COMMIT=${PLUGIN_COMMIT:-""}

# optionally, the sha1 of the elassandra commit, if applicable
# this will be used to tag the image.
# it is inferred from the base image if not set.
ELASSANDRA_COMMIT=${ELASSANDRA_COMMIT:-$(get_image_env ELASSANDRA_COMMIT)}

#---- output params ----
# If set, the images will be published to docker hub
DOCKER_PUBLISH=${DOCKER_PUBLISH:-false}

# Unless specified with a trailing slash, publish in the public strapdata docker hub
DOCKER_REGISTRY=${DOCKER_REGISTRY:-""}
# auto add slash to the end of registry if needed
if [ ! -z "${DOCKER_REGISTRY}" ] && [ "${DOCKER_REGISTRY: -1}" != "/" ]; then
  DOCKER_REGISTRY=${DOCKER_REGISTRY}/
fi

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

get_current_commit() {
  local repo=$1
  git rev-parse HEAD --git-path $repo | head -n1
}

if [ -n "$PLUGIN_DIR" ]; then
  # get the first zip package in the distribution folder of the git repository
  PACKAGE_SRC=$(ls ${PLUGIN_DIR}/distribution/target/releases/strapdata-enterprise-*.zip | head -n1 | cut -d " " -f1)

  # if plugin commit is not set, get the commit hash from the repository
  if [ -z "$PLUGIN_COMMIT" ]; then
    PLUGIN_COMMIT="$(get_current_commit $PLUGIN_DIR)"
  fi

elif [ -n "$PLUGIN_LOCATION" ] && [[ $PLUGIN_LOCATION = http* ]]; then
  # download the file from the web
  wget_plugin $PLUGIN_LOCATION

elif [ -n "$PLUGIN_LOCATION" ]; then
  # simply get the file from the local disk
  PLUGIN_SRC="$PLUGIN_LOCATION"

else
  echo "error: unreachable... you may report the issue"
  exit 1
fi

# extract the elassandra version name
PLUGIN_VERSION=$(echo ${PACKAGE_SRC} | sed 's/.*strapdata-enterprise\-\(.*\).zip/\1/')
ELASSANDRA_TAG=$(echo ${BASE_IMAGE} | sed 's/.*:\(.*\)/\1/')

# setup the tmp-build directory
mkdir -p tmp-build
cp ${PACKAGE_SRC} tmp-build/

# build the image
echo "Building elassandra-enterprise docker image for $BASE_IMAGE with strapack $PLUGIN_VERSION"
docker build --build-arg ENTERPRISE_PLUGIN_VERSION=${PLUGIN_VERSION} \
             --build-arg BASE_IMAGE=${BASE_IMAGE} \
             ${PLUGIN_COMMIT:+--build-arg ENTERPRISE_PLUGIN_COMMIT=${PLUGIN_COMMIT}} \
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

if [ ! -z "$ELASSANDRA_COMMIT" ] || [ ! -z "$PLUGIN_COMMIT" ]; then

  # concat the two commit hash (elassandra + strapack)
  commit_hash=$(echo ${ELASSANDRA_COMMIT:+E_$ELASSANDRA_COMMIT} | cut -c1-9)
  [ ! -z "$ELASSANDRA_COMMIT" ] && [ ! -z "$PLUGIN_COMMIT" ] && commit_hash="${commit_hash}-"
  commit_hash=${commit_hash}$(echo ${PLUGIN_COMMIT:+S_$PLUGIN_COMMIT} | cut -c1-9)

  docker tag ${DOCKER_IMAGE}:${ELASSANDRA_TAG} ${DOCKER_IMAGE}:${commit_hash}
  publish ${DOCKER_IMAGE}:${commit_hash}
fi
