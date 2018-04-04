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

sudo apt-get purge nodejs && sudo apt-get autoremove && sudo apt-get autoclean

# Source: http://yoember.com/nodejs/the-best-way-to-install-node-js/#on-linux
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash

ls -lah ~/.nvm/

# v8 is the active LTS release.
nvm use 8 || true
source $HOME/.nvm/nvm.sh
nvm install 8
node --version

# Increase the amount of inotify watches.
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

yarn global add ionic
yarn global add cordova