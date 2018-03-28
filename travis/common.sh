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