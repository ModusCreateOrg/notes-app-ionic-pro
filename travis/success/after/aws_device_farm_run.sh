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

declare PLATFORM

if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
    PLATFORM="ANDROID"
fi

# Get our device pool config based on the platform we are building for.
aws s3 cp s3://"${S3_CONFIG_BUCKET}"/"${PLATFORM,,}"-device-pool.json ./

# Create project
project_arn=$(aws devicefarm create-project \
    --name "${ANDROID_DEBUG_APK_NAME}" \
    --query 'project.arn' \
    --output text \
    --region us-west-2)

# Create device pool
device_pool_arn=$(aws devicefarm create-device-pool \
    --project-arn "${project_arn}" \
    --name "${PLATFORM,,}"-devices \
    --rules file://./"${PLATFORM,,}"-device-pool.json \
    --query 'devicePool.arn' \
    --output text \
    --region us-west-2)

# TODO: This var will vary depending on the paltform we are building for.
cd "${ANDROID_BUILD_LATEST_DIR}"

# Create an upload
# TODO: `type` should not be hard coded.
IFS=$' ' read -ra upload_meta <<< $(aws devicefarm create-upload \
    --name "${ANDROID_DEBUG_APK_NAME}" \
    --type ANDROID_APP \
    --project-arn "${project_arn}" \
    --query 'upload.[url,arn]' \
    --output text \
    --region us-west-2)
upload_url="${upload_meta[0]}"
upload_arn="${upload_meta[1]}"

# TODO: The variable `ANDROID_DEBUG_APK_NAME` will vary depending on how we build.
curl -T "${ANDROID_DEBUG_APK_NAME}" "${upload_url}"

# Schedule a run
# TODO: `--test` should come from a config file in an S3 bucket.
run_arn=$(aws devicefarm schedule-run \
        --project-arn "${project_arn}" \
        --app-arn "${upload_arn}" \
        --device-pool-arn "${device_pool_arn}" \
        --name "${TRAVIS_COMMIT_MESSAGE}" \
        --test '{"type":"BUILTIN_EXPLORER","testPackageArn":"'"${upload_arn}"'"}' \
        --query 'run.arn' \
        --output text \
        --region us-west-2)

# Get info on a run
get_run() {
    local run_arn
    run_arn=${1}

    IFS=$' ' read -ra run_meta <<< $(aws devicefarm get-run \
        --arn "$run_arn" \
        --query 'run.[status,arn,result,counters]' \
        --output text \
        --region us-west-2)
    echo "${run_meta[@]}"
}
declare -a get_run_output
IFS=$' ' read -ra get_run_output <<< $(get_run "$run_arn")
run_status="${get_run_output[0]}"
run_arn="${get_run_output[1]}"
run_result="${get_run_output[2]}"
run_overview="${get_run_output[3]}"

# Credits to Richard Bullington-McGuire (via monitor-deployment.sh in cloud-deployment-scripts)
echo "########## AWS Device Farm run started"
echo ""
progress=""
output=""
# See: https://docs.aws.amazon.com/cli/latest/reference/devicefarm/schedule-run.html#output
while [[ $run_status != "COMPLETED" ]]; do
    if [[ -n "$output" ]]; then
        sleep 5
    fi
    progress="${progress}."

    IFS=$' ' read -ra schedule_run_output <<< $(schedule_run "$project_arn" "$device_pool_arn" "$upload_arn")
    run_status="${schedule_run_output[0]}"
    run_arn="${schedule_run_output[1]}"
    run_result="${schedule_run_output[2]}"

    # Skip rewinding output if we are running under Travis,
    # the hint there is that TRAVIS will be defined
    if [[ -n "$output" ]] && [[ -z "${TRAVIS:-}" ]]; then
        rewind "$output"
    fi
    output=$(printf "%s\n%s" "$progress" "$run_overview")
    echo "$output"
done

echo "########## Test runs done with result \"$run_result\""

results=$(aws devicefarm list-jobs \
    --arn "$run_arn" \
    --output text \
    --region us-west-2)

# TODO: Maybe upload this to S3?
echo "$results"

aws devicefarm delete-project \
    --arn "${project_arn}" \
    --output text \
    --region us-west-2