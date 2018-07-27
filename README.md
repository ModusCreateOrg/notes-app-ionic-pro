[![Logo of the project](./images/modus.logo.svg)](https://moduscreate.com)

# Notes App Ionic Pro

[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![MIT Licensed](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/your/your-project/blob/master/LICENSE)

Code in Ionic, build in Jenkins/Travis and test on AWS Device Farm!
The source can be built via Jenkins or TravisCI (see [Jenkinsfile](./Jenkinsfile) & [.travis.yml](./.travis.yml) respectively), then tested on AWS Device Farm and uploaded to AWS S3.


## Developing

### Setting up Dev

When developing in Docker, we might also want to access AWS CLI and so we need to pass in the AWS credentials into our Docker container, as shown below:

```shell
# Make a copy of the environment file.
$ cp ./ci/env.sample ./ci/env.dev # You can make it `env.prod` or anything you want.

# Edit to add your own AWS credentials.
$ vim ./ci/env.dev

# Build the `ionic-ci-cd` image.
# ANDROID_API_LEVEL and ANDROID_BUILD_TOOLS_VERSION are optional.
$ docker build \
    --rm \
    -t ionic-ci-cd \
    --build-arg USER=$(id -un) \
    --build-arg GROUP=$(id -gn) \
    --build-arg UID=$(id -u) \
    --build-arg GID=$(id -g) \
    --build-arg ANDROID_API_LEVEL=26 \
    --build-arg ANDROID_BUILD_TOOLS_VERSION="26.0.2" \
    .

# Run the `ionic-jenkins-container` container, loading environment variables from the file `env.dev` into the container.
$ docker run \
    --rm \
    -it \
    --name=ionic-ci-cd-container \
    -v ${PWD}:$HOME/notes-app-ionic-pro \
    -w $HOME/notes-app-ionic-pro \
    --env-file ./ci/env.dev \
    ionic-ci-cd
```

The above should provide you with a Docker container within which you can begin developing.

## Style guide

To check for style compliance within shell scripts, use [shellcheck](https://github.com/koalaman/shellcheck):

```
# Searches for all files that end with '.sh' and runs them through 'shellcheck'
$ find ./ci/ -type f -name '*.sh' -exec shellcheck {} \;
```

## Modus Create

[Modus Create](https://moduscreate.com) is a digital product consultancy. We use a distributed team of the best talent in the world to offer a full suite of digital product design-build services; ranging from consumer facing apps, to digital migration, to agile development training, and business transformation.

[![Modus Create](./images/modus.logo.svg)](https://moduscreate.com)

## Licensing

This project is [MIT licensed](./LICENSE).
