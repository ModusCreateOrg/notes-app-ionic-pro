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

# Set up AWS CLI so that we can invoke AWS Device Farm tests.
# Credits: https://stackoverflow.com/a/44850245/379786
mkdir -p "${HOME}"/.aws

cat > "${HOME}"/.aws/credentials << EOL
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOL

# Device Farm is only available in region 'us-west-2'
# See: https://docs.aws.amazon.com/general/latest/gr/rande.html#devicefarm_region
cat > "${HOME}"/.aws/config << EOL
[default]
region = us-west-2
EOL