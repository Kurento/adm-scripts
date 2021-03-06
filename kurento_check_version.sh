#!/usr/bin/env bash



# Shell setup
# -----------

BASEPATH="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"  # Absolute canonical path
# shellcheck source=bash.conf.sh
source "$BASEPATH/bash.conf.sh" || exit 1

log "==================== BEGIN ===================="

# Trace all commands
set -o xtrace



# Force creating a Git tag when a Release version is detected.
# This is default 'false' because sometimes we need to do several actual
# changes before being able to mark a commit as an official Release.
if [ -n "${1:-}" ]; then
  CREATE_TAG="$1"
else
  if [ -z "${CREATE_TAG:-}" ]; then
    CREATE_TAG="false"
  fi
fi

[ -n "${CHECK_SUBMODULES:-}" ] || CHECK_SUBMODULES="yes"

# Path information
BASEPATH="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"  # Absolute canonical path
PATH="${BASEPATH}:${PATH}"

log "Create tag is '$CREATE_TAG'"

PROJECT_VERSION="$(kurento_get_version.sh)" || {
  log "ERROR: Command failed: kurento_get_version"
  exit 1
}
log "PROJECT_VERSION: $PROJECT_VERSION"

if [ "${PROJECT_VERSION}x" = "x" ]; then
  log "ERROR: Could not find project version"
  exit 1
fi

if [[ ${PROJECT_VERSION} == *-SNAPSHOT ]]; then
  log "Exit: Version is SNAPSHOT: ${PROJECT_VERSION}"
  exit 0
fi

if [[ ${PROJECT_VERSION} == *-dev ]]; then
  log "Exit: Version is DEV"
  exit 0
fi

if [[ $(echo "$PROJECT_VERSION" | grep -o '\.' | wc -l) -gt 2 ]]
then
  log "Exit: Found more than two dots, should be a configure.ac dev version"
  exit 0
fi

# Check if all submodules are in a tag
if [[ "${CHECK_SUBMODULES}" == "yes" ]]; then
  git submodule foreach "
    if [ x = \"x\`git tag --contains HEAD | head -1\`\" ]; then
      exit 1
    fi
  "
  if [ $? -eq 1 ]; then
    log "ERROR: Not all the projects are in a tag"
    exit 1
  fi
fi

if [ -f debian/changelog ]; then
  # check changelog version
  #ver=$(head -1 debian/changelog | sed -e "s@.* (\(.*\)) .*@\1@")
  CHG_VER="$(dpkg-parsechangelog --show-field Version)"
  if [[ "${CHG_VER%%-*}" != "${PROJECT_VERSION}" ]]; then
    log "WARNING Version in changelog is different to current version"
    #exit 1
  fi
fi

# Check that release version conforms to semver
kurento_check_semver.sh "${PROJECT_VERSION}" || {
  log "ERROR: Command failed: kurento_check_semver"
  exit 1
}

if [[ "$CREATE_TAG" == "true" ]]; then
  TAG_MSG="Tag version $PROJECT_VERSION"
  TAG_NAME="$PROJECT_VERSION"
  log "Create git tag: '$TAG_NAME'"
  if git tag -a -m "$TAG_MSG" "$TAG_NAME"; then
    log "Tag created, push to remote"
    git push origin "$TAG_NAME"
  else
    log "ERROR: Command failed: git tag $TAG_NAME"
    exit 1
  fi
fi



log "==================== END ===================="
