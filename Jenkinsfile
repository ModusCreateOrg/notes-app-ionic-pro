#!/usr/bin/env groovy

def APP_NAME = 'notes-app-ionic-pro'
def APP_REPO = 'notes-app-ionic-pro'
def APP_REPO_URL = "https://github.com/ModusCreateOrg/${APP_REPO}"
def APP_DEFAULT_BRANCH = 'master'
def AWS_DEV_CREDENTIAL_ID = '38613aab-24e4-4c2f-bf84-92a5b04d07c9'
def CONTAINER_ANDROID_BUILD_DIR
def HOST_ANDROID_BUILD_DIR
def ANDROID_DEBUG_APK_NAME
def default_timeout_minutes = 10
def uid
def gid
def user
def group

node {
    uid = sh(returnStdout: true, script: 'id -u').trim()
    gid = sh(returnStdout: true, script: 'id -g').trim()
    user = sh(returnStdout: true, script: 'id -un').trim()
    group = sh(returnStdout: true, script: 'id -gn').trim()

    CONTAINER_ANDROID_BUILD_DIR="$HOME/builds/platforms/android/build/outputs/apk/debug"
    HOST_ANDROID_BUILD_DIR="${env.WORKSPACE}/${APP_REPO}/platforms/android/build/outputs/apk/debug"
    ANDROID_DEBUG_APK_NAME="jenkins-android-debug-${env.BUILD_NUMBER}"
}

properties([
    parameters([
        string(name: 'git_branch_tag_or_commit',
               description: "Git Branch, Tag, or Commit reference for ${APP_REPO} (${APP_NAME})",
               defaultValue: APP_DEFAULT_BRANCH),
        string(name: 's3_config_bucket',
               description: "The S3 bucket that contains the cofiguration for AWS DeviceFarm",
               defaultValue: 'device-farm-configs-976851222302'),
        string(name: 's3_build_bucket',
               description: "The S3 bucket to which builds and DeviceFarm reports will be uploaded to",
               defaultValue: 'device-farm-builds-976851222302')
    ])
])

stage('Checkout') {
    node {
        timeout(time:default_timeout_minutes, unit:'MINUTES') {
            dir(APP_REPO) {
                // TODO: Just use `checkout scm`
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "${git_branch_tag_or_commit}"]],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [],
                    submoduleCfg: [],
                    userRemoteConfigs: [[
                        credentialsId: 'd52afb0b-bd8b-4705-89a5-fba502b8ac7d',
                        url: 'https://github.com/ModusCreateOrg/notes-app-ionic-pro'
                    ]]
                ])
                sh ('git clean -fdx')
                commitMessage = sh (
                    script: 'git log -1 --pretty=%B',
                    returnStdout: true
                ).trim()
            }
            stash includes: "${APP_REPO}/**", excludes: "${APP_REPO}/.git/", name: 'src'
        }
    }
}

// TODO: We could use the `dockerfile` agent.
// See:
//  1. https://jenkins.io/doc/book/pipeline/syntax/#agent
//  2. https://jenkins.io/doc/book/pipeline/docker/
stage('Run build') {
    node {
        unstash 'src'
        dir(APP_REPO) {
            // TODO: We should be getting a built image from the Docker registry.
            sh ("docker build -t ionic-jenkins --build-arg USER=${user} --build-arg GROUP=${group} --build-arg UID=${uid} --build-arg GID=${gid} ./ci/")
            sh ("docker run --rm -v ${env.WORKSPACE}/${APP_REPO}:$HOME/builds -w $HOME/builds -e BUILD_NUMBER=$BUILD_NUMBER ionic-jenkins ./ci/script/before/run.sh")
        }
        // Anrdoid .apk is built here.
        // TODO: Consider External Workspace Manager plugin since files may be large.
        // See: https://jenkins.io/doc/pipeline/steps/workflow-basic-steps/#code-stash-code-stash-some-files-to-be-used-later-in-the-build
        stash includes: "${APP_REPO}/platforms/android/build/outputs/apk/debug/**, ${APP_REPO}/ci/**", name: 'build'
    }
}

stage('Run test') {
    node {
        unstash 'build'
        dir(APP_REPO) {
            sh ("docker run --rm -v ${env.WORKSPACE}/${APP_REPO}:$HOME/builds -w $HOME/builds ionic-jenkins ./ci/script/aws_device_farm_run.sh '${commitMessage}' '${s3_config_bucket}' '${ANDROID_DEBUG_APK_NAME}' '${CONTAINER_ANDROID_BUILD_DIR}'")
        }
        // Artifacts (reports) are downloaded here:
        stash includes: "${APP_REPO}/platforms/android/build/outputs/apk/debug/**", name: 'artifacts'
    }
}

stage('Run deploy') {
    node {
        unstash 'artifacts'
        dir(APP_REPO) {
            sh ("aws s3 cp '${HOST_ANDROID_BUILD_DIR}/latest' s3://${s3_build_bucket}/ --recursive")
        }
    }
}