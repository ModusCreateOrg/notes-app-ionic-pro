#!/usr/bin/env groovy

def APP_NAME = 'notes-app-ionic-pro'
def APP_REPO = 'notes-app-ionic-pro'
def APP_REPO_URL = "https://github.com/ModusCreateOrg/${APP_REPO}"
def APP_DEFAULT_BRANCH = 'master'
def default_timeout_minutes = 10

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
        sh ('docker run --rm -v $PWD:/root/builds -w /root/builds ***REMOVED*** /root/builds/ci/build/run.sh')
        stash includes: '${APP_REPO}/platforms/android/build/outputs/apk/debug/**', name: 'build'
    }
}

stage('Run test') {
    node {
        unstash 'build'
        sh ('./ci/install/before/aws_cli_configure.sh')
        sh ('./ci/script/aws_device_farm_run.sh linux "${commitMessage}" 1')
        stash includes: '${APP_REPO}/platforms/android/build/outputs/apk/debug/**', name: 'report'
    }
}

stage('Run deploy') {
    node {
        unstash 'report'
        // Upload to S3
    }
}