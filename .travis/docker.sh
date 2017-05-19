#!/usr/bin/env bash
set -e

APP_NAME='fennec'

# Skip this step for jobs that don't run exunit
test "${PRESET}" == "test" || exit 0

MIX_ENV=prod mix docker.build
MIX_ENV=prod mix docker.release

DOCKERHUB_TAG="${TRAVIS_BRANCH//\//-}"

if [ "${TRAVIS_PULL_REQUEST}" != 'false' ]; then
    DOCKERHUB_TAG="PR-${TRAVIS_PULL_REQUEST}"
elif [ "${TRAVIS_BRANCH}" == 'master' ]; then
    DOCKERHUB_TAG="latest";
fi

TARGET_IMAGE="${DOCKERHUB_REPOSITORY}/${APP_NAME}:${DOCKERHUB_TAG}"

if [ "${TRAVIS_SECURE_ENV_VARS}" == 'true' ]; then
  docker login -u "${DOCKERHUB_USER}" -p "${DOCKERHUB_PASS}"
  docker tag ${APP_NAME}:release "${TARGET_IMAGE}"
  docker push "${TARGET_IMAGE}"
fi
