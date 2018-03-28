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

# TODO: Use `aws iam get-user` to display more info.
echo "Uploading build from branch '$TRAVIS_BRANCH' to S3 bucket '$S3_BUILD_BUCKET'"

# Move the .apk file to a dir on its own since the entire dir will be uploaded
# to the S3 bucket.
mv \
    "${ANDROID_BUILD_DIR}"/android-debug.apk \
    "${ANDROID_BUILD_LATEST_DIR}"/"${ANDROID_DEBUG_APK_NAME}".apk