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
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC1090
. "$DIR/../common.sh"

declare COMMIT_MESSAGE
declare S3_CONFIG_BUCKET
declare PACKAGE_NAME
declare BUILD_DIR
declare BUILD_DIR_LATEST
declare FORMAT

COMMIT_MESSAGE="${1:?'Missing commit message.'}"
S3_CONFIG_BUCKET="${2:?'Missing S3 config bucket.'}"
PACKAGE_NAME="${3:?'Missing package name.'}"
BUILD_DIR="${4:?'Missing build directory location.'}"
BUILD_DIR_LATEST="${BUILD_DIR}/latest"
# Output format of aws commands.
# See: https://docs.aws.amazon.com/cli/latest/userguide/controlling-output.html#text-output
FORMAT="text"
# The region that AWS Device Farm operates in.
# See: https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/
AWS_DF_REGION="us-west-2"

case $(uname -s) in
    Linux)
        PLATFORM="ANDROID"
        UPLOAD_TYPE="ANDROID_APP"
        PACKAGE_EXT="apk"
        mv "${BUILD_DIR}"/android-debug."${PACKAGE_EXT}" "${BUILD_DIR}/${PACKAGE_NAME}.${PACKAGE_EXT}"
    ;;

    Darwin)
        PLATFORM="IOS"
        UPLOAD_TYPE="IOS_APP"
        PACKAGE_EXT="ipa"
        # TODO
    ;;

    *)
        echo "Unknown OS"
        exit 1
    ;;
esac
# From here onwards, `PLATFORM` will need to be lower case.
PLATFORM="${PLATFORM,,}"

# Get our configs from S3
declare CONF_DIR
CONF_DIR=$(mktemp -d)
aws s3 cp \
  s3://"${S3_CONFIG_BUCKET}"/"${PLATFORM}"/device-pool.json \
  "${CONF_DIR}"/"${PLATFORM}"/device-pool.json
aws s3 cp \
  s3://"${S3_CONFIG_BUCKET}"/tests/BUILTIN_EXPLORER.jinja2 \
  "${CONF_DIR}"/tests/BUILTIN_EXPLORER.jinja2

# Create project
declare PROJECT_ARN
PROJECT_ARN=$(aws devicefarm create-project \
    --name "${PACKAGE_NAME}.${PACKAGE_EXT}" \
    --query 'project.arn' \
    --output "${FORMAT}" \
    --region "${AWS_DF_REGION}")

# Create device pool
declare DEVICE_POOL_ARN
DEVICE_POOL_ARN=$(aws devicefarm create-device-pool \
    --project-arn "${PROJECT_ARN}" \
    --name "${PLATFORM}"-devices \
    --rules file://"${CONF_DIR}"/"${PLATFORM}"/device-pool.json \
    --query 'devicePool.arn' \
    --output "${FORMAT}" \
    --region "${AWS_DF_REGION}")

cd "${BUILD_DIR}"

# Create an upload
declare -a UPLOAD_META
declare UPLOAD_URL
declare UPLOAD_ARN
# shellcheck disable=SC2046
IFS=$' ' read -ra UPLOAD_META <<< $(aws devicefarm create-upload \
    --name "${PACKAGE_NAME}.${PACKAGE_EXT}" \
    --type "${UPLOAD_TYPE}" \
    --project-arn "${PROJECT_ARN}" \
    --query 'upload.[url,arn]' \
    --output "${FORMAT}" \
    --region "${AWS_DF_REGION}")
UPLOAD_URL="${UPLOAD_META[0]}"
UPLOAD_ARN="${UPLOAD_META[1]}"

curl -T "${BUILD_DIR}/${PACKAGE_NAME}.${PACKAGE_EXT}" "${UPLOAD_URL}"

# Schedule a run
declare TEST_FILE
echo "{\"upload_arn\":\"$UPLOAD_ARN\"}" > "${CONF_DIR}"/upload_arn.json
TEST_FILE=$(jinja2 \
    "${CONF_DIR}"/tests/BUILTIN_EXPLORER.jinja2 \
    "${CONF_DIR}"/upload_arn.json \
    --format=json)
# We trim the commit message down to 256 characters since that's the character
# constraint for the `name` option.
# See: https://docs.aws.amazon.com/devicefarm/latest/APIReference/API_ScheduleRun.html#devicefarm-ScheduleRun-request-name
declare RUN_ARN
RUN_ARN=$(aws devicefarm schedule-run \
        --project-arn "${PROJECT_ARN}" \
        --app-arn "${UPLOAD_ARN}" \
        --device-pool-arn "${DEVICE_POOL_ARN}" \
        --name "${COMMIT_MESSAGE:0:256}" \
        --test "${TEST_FILE}" \
        --query 'run.arn' \
        --output "${FORMAT}" \
        --region "${AWS_DF_REGION}")

# Get info on a run
get_run() {
    local run_arn
    run_arn="${1}"

    aws devicefarm get-run \
        --arn "$run_arn" \
        --query 'run.[status,arn,result,counters]' \
        --output json \
        --region "${AWS_DF_REGION}"
}

declare GET_RUN_OUTPUT
declare RUN_STATUS
declare RUN_RESULT
declare RUN_OVERVIEW
GET_RUN_OUTPUT=$(get_run "$RUN_ARN")
RUN_STATUS=$(echo "$GET_RUN_OUTPUT" | jq -r '.[0]')
RUN_RESULT=$(echo "$GET_RUN_OUTPUT" | jq -r '.[2]')
RUN_OVERVIEW=$(echo "$GET_RUN_OUTPUT" | jq -r '.[3]')

echo "########## AWS Device Farm run started"
echo ""
declare PROGRESS
declare OUTPUT
PROGRESS=""
OUTPUT=""
# See: https://docs.aws.amazon.com/cli/latest/reference/devicefarm/get-run.html#output
while [[ $RUN_STATUS != "COMPLETED" ]]; do
    if [[ -n "$OUTPUT" ]]; then
        sleep 30
    fi
    PROGRESS="${PROGRESS}."
    GET_RUN_OUTPUT=$(get_run "$RUN_ARN")
    RUN_STATUS=$(echo "$GET_RUN_OUTPUT" | jq -r '.[0]')
    RUN_RESULT=$(echo "$GET_RUN_OUTPUT" | jq -r '.[2]')
    RUN_OVERVIEW=$(echo "$GET_RUN_OUTPUT" | jq -r '.[3]')

    OUTPUT=$(printf "%s\n%s" "$PROGRESS" "$RUN_OVERVIEW")
    echo "$OUTPUT"
done
echo "########## Test runs completed with result \"$RUN_RESULT\""

declare RESULTS
declare HEADER
declare -i RES_LENGTH
declare CONTENT
declare -i COUNTER
declare RES_DEVICE
declare RES_ROOT
declare -i RES_DEVICE_MINUTES
RESULTS=$(aws devicefarm list-jobs \
    --arn "${RUN_ARN}" \
    --output json \
    --region "${AWS_DF_REGION}")
HEADER="Name|Model|Form|Operating System|Resolution|RAM/CPU|Result|Duration\n"
RES_LENGTH=$(echo "${RESULTS}" | jq '.jobs | length')
CONTENT=""
COUNTER=0
while [[ $COUNTER -lt "$RES_LENGTH" ]]; do
    RES_DEVICE=$(echo "${RESULTS}" | jq -r ".jobs[$COUNTER].device | {
        # The device's display name.
        name,
        # The device's model ID.
        modelId,
        # The device's form factor.
        formFactor,
        # The device's platform and the device's operating system type.
        \"os\": \"\(.platform) \(.os)\",
        # The resolution of the device, expressed in pixels.
        \"resolution\": \"\(.resolution.width)x\(.resolution.height)\",
        # The device's total memory size converted bytes to GB and
        # the clock speed of the device's CPU converted from Hz to GHz.
        \"memory\": \"\(.memory / 1000 / 1000 / 1000|tostring + \"GB\")/\(.cpu[\"clock\"] * .10 + 0.5|floor/100.0|tostring + \"GHz\")\"
    } | join(\"|\")")

    # The job's result.
    RES_ROOT=$(echo "$RESULTS" | jq -r ".jobs[$COUNTER].result")
    # The total minutes used by the resource to run tests.
    RES_DEVICE_MINUTES=$(echo "$RESULTS" | jq -r ".jobs[$COUNTER].deviceMinutes.total|tostring + \" mins\"")

    CONTENT="${CONTENT}${RES_DEVICE}|${RES_ROOT}|${RES_DEVICE_MINUTES}\n"
    let COUNTER=COUNTER+1
done

echo -e "${HEADER}${CONTENT}" | column -c80 -s"|" -t

# Fail the build if it doesn't pass.
if [[ "${RUN_RESULT}" == "ERRORED" ]] || [[ "${RUN_RESULT}" == "FAILED" ]]; then
    echo "Terminating build"
    exit 1
fi

# Move the built file to a dir on its own since the entire dir will be uploaded
# to the S3 bucket.
rm -rf "${BUILD_DIR_LATEST}"
mkdir -p "${BUILD_DIR_LATEST}"
mv \
    "${BUILD_DIR}/${PACKAGE_NAME}.${PACKAGE_EXT}" \
    "${BUILD_DIR_LATEST}/${PACKAGE_NAME}.${PACKAGE_EXT}"

# Download test artifacts. S3 will upload it in the `deploy` step.
declare TYPE
declare ARTIFACT
declare ARTIFACT_URL
declare ARTIFACT_TYPE
declare ARTIFACT_EXT
declare ARTIFACT_NAME
declare ARTIFACT_FILENAME
COUNTER=0
for TYPE in FILE SCREENSHOT; do
    while read -r ARTIFACT; do
        ARTIFACT_URL=$(echo "$ARTIFACT" | jq -r '.url')
        ARTIFACT_TYPE=$(echo "$ARTIFACT" | jq -r '.type')
        ARTIFACT_EXT=$(echo "$ARTIFACT" | jq -r '.extension')
        ARTIFACT_NAME=$(echo "$ARTIFACT" | jq -r '.name')
        ARTIFACT_FILENAME="${ARTIFACT_NAME}-${RANDOM}.${ARTIFACT_EXT}"

        mkdir -p "${BUILD_DIR_LATEST}/${PACKAGE_NAME}/${ARTIFACT_TYPE}"
        set +e
        try_with_backoff curl -sSo \
            "${BUILD_DIR_LATEST}/${PACKAGE_NAME}/${ARTIFACT_TYPE}/${ARTIFACT_FILENAME}" \
            "${ARTIFACT_URL}"
        set -e
        let COUNTER=COUNTER+1
    done < <(aws devicefarm list-artifacts \
        --arn "${RUN_ARN}" \
        --type "${TYPE}" \
        --output json \
        --region "${AWS_DF_REGION}" \
        | jq -cr '.[] | .[] | {url: .url, type: .type, extension: .extension, name: .name}')
done

echo "${RESULTS}" > "${BUILD_DIR_LATEST}/${PACKAGE_NAME}/list-jobs.json"

aws devicefarm delete-project \
    --arn "${PROJECT_ARN}" \
    --output json \
    --region "${AWS_DF_REGION}"
