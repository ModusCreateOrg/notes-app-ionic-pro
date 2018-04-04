#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
# set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
declare DIR
# shellcheck disable=SC2034
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

use_nodejs 8

yarn install
# TODO: Figure out why we have to remove android and add it for this to work.
# See: https://travis-ci.org/ModusCreateOrg/notes-app-ionic-pro/builds/359512339#L3329
# ionic cordova platform remove android
# ionic cordova platform add android --nofetch
ionic cordova platform add android
ionic cordova build android