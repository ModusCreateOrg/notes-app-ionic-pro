#!/usr/bin/env groovy

def APP_NAME = 'notes-app-ionic-pro'
def APP_REPO = 'notes-app-ionic-pro'
def APP_REPO_URL = "https://github.com/ModusCreateOrg/${APP_REPO}"
def APP_DEFAULT_BRANCH = 'master'
def AWS_DEV_CREDENTIAL_ID = '38613aab-24e4-4c2f-bf84-92a5b04d07c9'
def S3_CONFIG_BUCKET = 'device-farm-configs-976851222302'
def ANDROID_BUILD_DIR="${WORKSPACE}/platforms/android/build/outputs/apk/debug"
def ANDROID_DEBUG_APK_NAME="android-debug-${BUILD_NUMBER}-${BUILD_ID}"
def ANDROID_BUILD_LATEST_DIR="${ANDROID_BUILD_DIR}/latest"
def default_timeout_minutes = 10

def wrapStep = { steps ->
    withCredentials([usernamePassword(credentialsId: AWS_DEV_CREDENTIAL_ID,
                                      passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                                      usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm', 'defaultFg': 1, 'defaultBg': 2]) {
              // This is the current syntax for invoking a build wrapper, naming the class.
              wrap([$class: 'TimestamperBuildWrapper']) {
                  steps()
              }
        }
    }
}

properties([
    parameters([
        string(name: 'git_branch_tag_or_commit', 
               description: 'Git Branch, Tag, or Commit reference for ${APP_REPO} (${APP_NAME})',
               defaultValue: APP_DEFAULT_BRANCH)
    ])
])

stage('Checkout') {
    node {
        timeout(time:default_timeout_minutes, unit:'MINUTES') {
            dir(APP_REPO) {
                sh ('env')
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '${deploy_git_branch_tag_or_commit}']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [],
                    submoduleCfg: [],
                    userRemoteConfigs: [[
                        credentialsId: 'd52afb0b-bd8b-4705-89a5-fba502b8ac7d',
                        url: 'https://github.com/ModusCreateOrg/notes-app-ionic-pro'
                    ]]
                ])
                sh ('git clean -fdx')
                def commitMessage = sh (
                    script: 'git log -1 --pretty=%B',
                    returnStdout: true
                ).trim()
            }
            stash includes: '${APP_REPO}/**', excludes: '${APP_REPO}/.git/', name: 'src'
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
        // TODO: We should be getting a built image from the Docker registry.
        sh ('docker build -t ***REMOVED*** ./ci/')
        sh ("docker run --rm -v $PWD:/root/builds -w /root/builds ***REMOVED*** /root/builds/ci/build/run.sh")

        // Anrdoid .apk is built here:
        stash includes: '${APP_REPO}/platforms/android/build/outputs/apk/debug/**', name: 'build'
    }
}

stage('Run test') {
    node {
        unstash 'build'
//        sh ('./ci/install/before/aws_cli_configure.sh')
        wrapStep({
            sh ("./ci/script/aws_device_farm_run.sh linux '${commitMessage}' 1")
        })

        // Artifacts (reports) are downloaded here:
        stash includes: '${APP_REPO}/platforms/android/build/outputs/apk/debug/**', name: 'artifacts'
    }
}

stage('Run deploy') {
    node {
        unstash 'artifacts'
        sh ('aws s3 ls s3://device-farm-builds-976851222302/ --region us-east-1')
    }
}