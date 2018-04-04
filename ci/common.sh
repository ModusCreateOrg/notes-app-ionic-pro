#!/usr/bin/env bash

# Retries a command a with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the
# initial backoff timeout is given by TIMEOUT in seconds
# (default 1.)
#
# Successive backoffs double the timeout.
# Beware of set -e killing your whole script!
#
# Thanks to Coderwall
#   --> https://coderwall.com/p/--eiqg/exponential-backoff-in-bash
try_with_backoff() {
    local max_attempts
    local timeout_duration
    local attempt
    local exitCode

    max_attempts=${ATTEMPTS-6}
    timeout_duration=${TIMEOUT-1}
    attempt=0
    exitCode=0

    while [[ $attempt < $max_attempts ]]; do
        "$@"
        exitCode=$?

        if [[ $exitCode == 0 ]]; then
            break
        fi

        echo "Failure! Retrying in $timeout_duration.." 1>&2
        sleep "$timeout_duration"
        attempt=$(( attempt + 1 ))
        timeout_duration=$(( timeout_duration * 2 ))
    done

    if [[ $exitCode != 0 ]]; then
        #shellcheck disable=SC2145
        echo "You've failed me for the last time! ($@)" 1>&2
    fi

    return $exitCode
}

install_nodejs() {
    sudo apt-get purge nodejs && sudo apt-get autoremove && sudo apt-get autoclean

    # Source: http://yoember.com/nodejs/the-best-way-to-install-node-js/#on-linux
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
}

use_nodejs() {
    local version
    # v8 is the active LTS release.
    version=${1:-8}

    nvm use ${version} || true
    source $HOME/.nvm/nvm.sh
    nvm install ${version}
    node --version
}