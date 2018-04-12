#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
declare DIR
# shellcheck disable=SC2034
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/../../common.sh"

# If we are running in Jenkins, run fixuid.
# See: https://github.com/boxboat/fixuid#run-in-startup-script-instead-of-entrypoint
# if [[ ! -z "${BUILD_NUMBER:-}" ]]; then
    echo "Running fixuid..."
    eval $( fixuid )
# fi

use_node 8

yarn install
ionic cordova platform add android
ionic cordova build android