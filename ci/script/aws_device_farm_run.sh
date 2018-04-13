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

. "$DIR/../common.sh"

declare COMMIT_MESSAGE
declare S3_CONFIG_BUCKET
declare ANDROID_DEBUG_APK_NAME
declare ANDROID_BUILD_DIR
declare ANDROID_BUILD_LATEST_DIR

COMMIT_MESSAGE="${1:?'You must specify the commit message.'}"
S3_CONFIG_BUCKET="${2:?'You must specify the S3 config bucket.'}"
ANDROID_DEBUG_APK_NAME="${3}"
ANDROID_BUILD_DIR="${4}"
ANDROID_BUILD_LATEST_DIR="${ANDROID_BUILD_DIR}/latest"

case $(uname -s) in
    Linux)
        PLATFORM="ANDROID"
    ;;

    Darwin)
        PLATFORM="IOS"
    ;;

    *)
        echo "Unknown OS"
        exit 1
    ;;
esac

config_dir=$(mktemp -d)
# Get our configs from S3
aws s3 cp s3://"${S3_CONFIG_BUCKET}"/"${PLATFORM,,}"-device-pool.json "${config_dir}"/"${PLATFORM,,}"-device-pool.json
aws s3 cp s3://"${S3_CONFIG_BUCKET}"/test-BUILTIN_EXPLORER.jinja2 "${config_dir}"/test-BUILTIN_EXPLORER.jinja2

# Create project
project_arn=$(aws devicefarm create-project \
    --name "${ANDROID_DEBUG_APK_NAME}".apk \
    --query 'project.arn' \
    --output text \
    --region us-west-2)

# Create device pool
device_pool_arn=$(aws devicefarm create-device-pool \
    --project-arn "${project_arn}" \
    --name "${PLATFORM,,}"-devices \
    --rules file://"${config_dir}"/"${PLATFORM,,}"-device-pool.json \
    --query 'devicePool.arn' \
    --output text \
    --region us-west-2)

# TODO: This var will vary depending on the platform we are building for.
cd "${ANDROID_BUILD_DIR}"

# Create an upload
# TODO: `type` should not be hard coded.
IFS=$' ' read -ra upload_meta <<< $(aws devicefarm create-upload \
    --name "android-debug.apk" \
    --type ANDROID_APP \
    --project-arn "${project_arn}" \
    --query 'upload.[url,arn]' \
    --output text \
    --region us-west-2)
upload_url="${upload_meta[0]}"
upload_arn="${upload_meta[1]}"

# TODO: The file to be uploaded will vary depending on how we build and the platform.
curl -T "${ANDROID_BUILD_DIR}"/android-debug.apk "${upload_url}"

# Schedule a run
echo "{\"upload_arn\":\"$upload_arn\"}" > "${config_dir}"/upload_arn.json
test_file=$(jinja2 \
    "${config_dir}"/test-BUILTIN_EXPLORER.jinja2 \
    "${config_dir}"/upload_arn.json \
    --format=json)
run_arn=$(aws devicefarm schedule-run \
        --project-arn "${project_arn}" \
        --app-arn "${upload_arn}" \
        --device-pool-arn "${device_pool_arn}" \
        --name "${COMMIT_MESSAGE}" \
        --test "$test_file" \
        --query 'run.arn' \
        --output text \
        --region us-west-2)

# Get info on a run
get_run() {
    local run_arn
    run_arn="${1}"

    aws devicefarm get-run \
        --arn "$run_arn" \
        --query 'run.[status,arn,result,counters]' \
        --output json \
        --region us-west-2
}
declare -a get_run_output
get_run_output=$(get_run "$run_arn")
run_status=$(echo "$get_run_output" | jq -r '.[0]')
# run_arn=$(echo "$get_run_output" | jq -r '.[1]')
run_result=$(echo "$get_run_output" | jq -r '.[2]')
run_overview=$(echo "$get_run_output" | jq -r '.[3]')

# Credits to Richard Bullington-McGuire (via monitor-deployment.sh in cloud-deployment-scripts)
echo "########## AWS Device Farm run started"
echo ""
progress=""
output=""
# TODO: Check to see if I should checking for other run_status types
# See: https://docs.aws.amazon.com/cli/latest/reference/devicefarm/get-run.html#output
while [[ $run_status != "COMPLETED" ]]; do
    if [[ -n "$output" ]]; then
        sleep 5
    fi
    progress="${progress}."
    get_run_output=$(get_run "$run_arn")
    run_status=$(echo "$get_run_output" | jq -r '.[0]')
    # run_arn=$(echo "$get_run_output" | jq '.[1]')
    run_result=$(echo "$get_run_output" | jq -r '.[2]')
    run_overview=$(echo "$get_run_output" | jq -r '.[3]')

    # Skip rewinding output if we are running in Jenkins or Travis.
    if [[ -n "$output" ]] && [[ -z "${BUILD_NUMBER:-}" ]] && [[ -z "${TRAVIS:-}" ]]; then
        rewind "$output"
    fi
    output=$(printf "%s\n%s" "$progress" "$run_overview")
    echo "$output"
done
echo "########## Test runs done with result \"$run_result\""

set -x
# TODO: Test this
# Fail the build if it doesn't pass.
if [[ $run_result == "ERRORED" ]] || [[ $run_result == "FAILED" ]]; then
    echo "Terminating build"
    exit 1

    env

    echo "TRAVIS IS: $TRAVIS"

    # Unlike Jenkins, Travis doesn't terminate on a Bash `exit` so we have to
    # cancel it manually.
    # See: https://blog.travis-ci.com/2013-08-21-abort-mission-cancel-running-builds
    # See: https://github.com/travis-ci/travis.rb#cancel
    if [[ ! -z "${TRAVIS:-}" ]]; then
        travis cancel "${TRAVIS_BUILD_NUMBER}"
    fi
fi
set +x

# TODO: Show more info like: https://aws.amazon.com/blogs/mobile/get-started-with-the-aws-device-farm-cli-and-calabash-part-2-retrieving-reports-and-artifacts/
results=$(aws devicefarm list-jobs \
    --arn "$run_arn" \
    --output json \
    --region us-west-2)

# TODO: Maybe upload this to S3?
echo "JOBS: $results"

# Move the .apk file to a dir on its own since the entire dir will be uploaded
# to the S3 bucket.
rm -rf "${ANDROID_BUILD_LATEST_DIR}"
mkdir -p "${ANDROID_BUILD_LATEST_DIR}"
mv \
    "${ANDROID_BUILD_DIR}"/android-debug.apk \
    "${ANDROID_BUILD_LATEST_DIR}"/"${ANDROID_DEBUG_APK_NAME}".apk

# Download test artifacts. S3 will upload it in the `deploy` step.
COUNTER=0
for type in FILE SCREENSHOT; do
    while read i; do
        artifact_url=$(echo "$i" | jq -r '.url')
        artifact_type=$(echo "$i" | jq -r '.type')
        artifact_ext=$(echo "$i" | jq -r '.extension')
        artifact_name=$(echo "$i" | jq -r '.name')
        artifact_filename="${artifact_name}-${RANDOM}.${artifact_ext}"

        mkdir -p "${ANDROID_BUILD_LATEST_DIR}/${ANDROID_DEBUG_APK_NAME}/${artifact_type}"
        set +e
        try_with_backoff wget -O "${ANDROID_BUILD_LATEST_DIR}/${ANDROID_DEBUG_APK_NAME}/${artifact_type}/${artifact_filename}" "${artifact_url}"
        set -e
        let COUNTER=COUNTER+1
    done < <(aws devicefarm list-artifacts \
        --arn "$run_arn" \
        --type "$type" \
        --output json \
        --region us-west-2 \
        | jq -cr '.[] | .[] | {url: .url, type: .type, extension: .extension, name: .name}')
done

aws devicefarm delete-project \
    --arn "${project_arn}" \
    --output json \
    --region us-west-2