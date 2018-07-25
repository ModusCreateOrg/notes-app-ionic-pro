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
    # Source: http://yoember.com/nodejs/the-best-way-to-install-node-js/#on-linux
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
}

use_node() {
    local nvm_installed
    local version
    # v8 is the active LTS release.
    version=${1:-8}

    set +e
    nvm use "${version}" 2>/dev/null
    nvm_installed=$?
    set -e

    if [[ $nvm_installed -ne 0 ]]; then
        # shellcheck disable=SC1090
        . "$HOME/.nvm/nvm.sh"
        nvm install "${version}"
        nvm use "${version}"
    fi
}

# Make debugging easier
# See: http://wiki.bash-hackers.org/scripting/debuggingtips#making_xtrace_more_useful
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
