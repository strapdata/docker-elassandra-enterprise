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

main() {

  init

  build

  run_tests

  publish
}


#-- initialization, parameters parsing --#
init() {

  # The script need the elassandra git repository where the deb package has been built
  REPO_DIR=${REPO_DIR}
  PACKAGE_LOCATION=${PACKAGE_LOCATION}
  # RELEASE_NAME=${RELEASE_NAME}
  if [ -z "$REPO_DIR" ] && [ -z "$PACKAGE_LOCATION" ] && [ -z "$RELEASE_NAME" ]; then
    echo "REPO_DIR must be set to the strapack repository directory (with zip package assembled inside)"
    echo "or PACKAGE_LOCATION must point to an url or path containing a strapack zip package"
    # echo "or RELEASE_NAME must be a valid release name on the github repository"
    exit 1
  fi


  # If set, the images will be published to docker hub
  DOCKER_PUBLISH=${DOCKER_PUBLISH:-false}

  # if set, tests will be ran before to push the image
  DOCKER_RUN_TESTS=${DOCKER_RUN_TESTS:-false}

  # Unless specified, publish in the public strapdata docker hub
  DOCKER_REGISTRY=${DOCKER_REGISTRY:-""}
  # auto add slash to the end of registry if needed
  if [ ! -z "${DOCKER_REGISTRY}" ] && [ "${DOCKER_REGISTRY: -1}" != "/" ]; then
    DOCKER_REGISTRY=${DOCKER_REGISTRY}/
  fi

  # If set, the images will be tagged latest
  DOCKER_LATEST=${DOCKER_LATEST:-false}

  # If set, the image is considered to be the latest relative to the major elasticsearch version (5 or 6).
  # Consequently, the image will be tagged with generic versions (for instance 6.2.3.4 will produce 6, 6.2 and 6.2.3)
  DOCKER_MAJOR_LATEST=${DOCKER_MAJOR_LATEST:-false}

  # set the docker hub repository name
  REPO_NAME=${REPO_NAME:-"strapdata/elassandra-enterprise"}

  # Options to add to docker build command
  DOCKER_BUILD_OPTS=${DOCKER_BUILD_OPTS:-"--rm"}

  # the base image to inherit from
  BASE_IMAGE_NAME=${BASE_IMAGE_NAME:-strapdata/elassandra}

  BASE_IMAGE_TAG=${BASE_IMAGE_TAG:-latest}

  if [ "$BASE_IMAGE" != "" ]; then
    echo "error: BASE_IMAGE is deprecated, you must use BASE_IMAGE_NAME and BASE_IMAGE_TAG instead"
    exit 1;
  fi
  BASE_IMAGE=$BASE_IMAGE_NAME:$BASE_IMAGE_TAG

  # if true, remove the image to re-download it.
  FORCE_PULL=${FORCE_PULL:-false}

  # pull the image if not present, or if FORCE_PULL=true
  if [ "$FORCE_PULL" = true ] || ! docker inspect --type=image $BASE_IMAGE > /dev/null; then
    docker rmi ${BASE_IMAGE} || true
    docker pull ${BASE_IMAGE}
  fi

  # the target names of the images
  DOCKER_IMAGE=${DOCKER_REGISTRY}${REPO_NAME}

  # optionally, the sha1 of the elassandra commit, if applicable
  # this will be used to tag the image.
  # it is inferred from the base image if not set.
  ELASSANDRA_COMMIT=${ELASSANDRA_COMMIT:-$(get_image_env ELASSANDRA_COMMIT)}

  # optionally, the sha1 of the strapack commit.
  # If REPO_DIR is set, it will be inferred from the git repository
  PLUGIN_COMMIT=${PLUGIN_COMMIT:-""}

  if [ -n "$REPO_DIR" ]; then
    # get the first strapack zip in the distributions folder of the git repository
    PACKAGE_SRC=$(ls ${REPO_DIR}/distribution/target/releases/strapdata-enterprise-*.zip | head -n1 | cut -d " " -f1)

    # if plugin commit is not set, get the commit hash from the repository
    if [ -z "$PLUGIN_COMMIT" ]; then
      PLUGIN_COMMIT="$(get_current_commit $REPO_DIR)"
    fi

  elif [ -n "$PACKAGE_LOCATION" ] && [[ $PACKAGE_LOCATION = http* ]]; then
    # download the file from the web
    wget_package $PACKAGE_LOCATION

  elif [ -n "$PACKAGE_LOCATION" ]; then
    # simply get the file from the local disk
    PACKAGE_SRC="$PACKAGE_LOCATION"

#  elif [ -n "$RELEASE_NAME" ]; then
#    # get the file from github release
#    get_release "$RELEASE_NAME"

  else
    echo "error: unreachable... you may report the issue"
    exit 1
  fi

  # the strapack elassandra version.
  PLUGIN_VERSION=${PLUGIN_VERSION:-$(basename ${PACKAGE_SRC} | sed 's/.*strapdata-enterprise\-\(.*\).zip$/\1/')}
  # the elassandra version.
  # if not set, it is inferred from the docker image env
  ELASSANDRA_VERSION=${ELASSANDRA_VERSION:-$(get_image_env ELASSANDRA_VERSION)}
  if [ -z $ELASSANDRA_VERSION ]; then
    echo "can't infer the elassandra version, missing env ELASSANDRA_VERSION" >&2
    exit 1
  fi
}


#-- build the image --#
build() {
  # setup the tmp-build directory
  mkdir -p tmp-build
  cp ${PACKAGE_SRC} tmp-build/strapdata-enterprise-${PLUGIN_VERSION}.zip

  # workaround for old docker version that does not support arg before from (such as the one installed on aks)
  if [ "$(docker version -f '{{.Server.Version}}' | cut -d'.' -f1)" -lt "17" ]; then
     sed -i 's/ARG BASE_IMAGE//g' Dockerfile
     sed -i 's~\${BASE_IMAGE}~'${BASE_IMAGE}'~g' Dockerfile
  fi

  # build the image
  echo "Building elassandra-enterprise docker image for $BASE_IMAGE with strapack $PLUGIN_VERSION"
  docker build --build-arg ENTERPRISE_PLUGIN_VERSION=${PLUGIN_VERSION} \
               --build-arg BASE_IMAGE=${BASE_IMAGE} \
               ${PLUGIN_COMMIT:+--build-arg ENTERPRISE_PLUGIN_COMMIT=${PLUGIN_COMMIT}} \
               ${DOCKER_BUILD_OPTS} -f Dockerfile -t "$DOCKER_IMAGE:$ELASSANDRA_VERSION" .

  # cleanup
  rm -rf tmp-build
}

#-- run basic tests --#
run_tests() {
  if [ "${DOCKER_RUN_TESTS}" = "true" ]; then
    ./run.sh "$DOCKER_IMAGE:$ELASSANDRA_VERSION"
  fi
}

#-- publish to registry --#
publish() {
 # tag and publish image if DOCKER_PUBLISH=true
  push ${DOCKER_IMAGE}:${ELASSANDRA_VERSION}

  if [ "$DOCKER_LATEST" = "true" ]; then
    tag_and_push latest
  fi

  if [ "$DOCKER_MAJOR_LATEST" = "true" ]; then
    tag_and_push "${ELASSANDRA_VERSION%.*.*.*}" # one digit version
    tag_and_push "${ELASSANDRA_VERSION%.*.*}" # two digit version
    tag_and_push "${ELASSANDRA_VERSION%.*}" # three digit version
  fi

  if [ ! -z "$ELASSANDRA_COMMIT" ] || [ ! -z "$PLUGIN_COMMIT" ]; then

    # concat the two commit hash (elassandra + strapack)
    commit_hash=$(echo ${ELASSANDRA_COMMIT:+E_$ELASSANDRA_COMMIT} | cut -c1-9)
    [ ! -z "$ELASSANDRA_COMMIT" ] && [ ! -z "$PLUGIN_COMMIT" ] && commit_hash="${commit_hash}-"
    commit_hash=${commit_hash}$(echo ${PLUGIN_COMMIT:+S_$PLUGIN_COMMIT} | cut -c1-9)
    tag_and_push ${commit_hash}
  fi
}

#-- utils --#
wget_package() {
  local url=$1
  mkdir -p tmp-cache
  # download the deb package into the cache folder
  # the -N option ensure we do not download the file when we already have an up-to-date copy locally
  wget -N $url -P tmp-cache/
  PACKAGE_SRC=tmp-cache/$(basename $url)
}

get_release() {
  local name=$1
  local base_url

  local url=https://github.com/$REPO_NAME/releases/download/v${name}/elassandra-${name}.deb

  wget_package $url
}

get_current_commit() {
  local repo=$1
  cd $repo
  local hash="$(git rev-parse HEAD | head -n1)"
  cd - > /dev/null
  echo "$hash"
}

push() {
  if [ "$DOCKER_PUBLISH" = true ]; then
    echo "Publishing $1"
    docker push ${1}
  fi
}

tag_and_push() {
  local tag=$1
  docker tag ${DOCKER_IMAGE}:${ELASSANDRA_VERSION} ${DOCKER_IMAGE}:${tag}
  push ${DOCKER_IMAGE}:${tag}
}

get_image_env() {
  local name=$1
  local image=${2:-${BASE_IMAGE}}
  local val=$(docker inspect -f  \
    '{{range $index, $value := .Config.Env}}{{println $value}}{{end}}' \
    $image | grep $name)
  echo ${val#"$name="}
}

main $@
