def gitUrl = System.getenv('SECURERAG_GIT_URL') ?: 'https://github.com/YassinoMed/MasterPFE.git'
def branchSpec = System.getenv('SECURERAG_GIT_BRANCH') ?: '*/main'

pipelineJob('securerag-hub-recette') {
    description('SecureRAG Hub — CI/CD pipeline with automatic deployment to the recette (staging) machine (63.250.59.72)')
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url(gitUrl)
                    }
                    branch(branchSpec)
                }
            }
            scriptPath('Jenkinsfile.recette')
        }
    }
    parameters {
        stringParam('RECETTE_HOST', '63.250.59.72', 'IP address or hostname of the recette (staging) machine.')
        stringParam('RECETTE_USER', 'root', 'SSH user on the recette machine.')
        booleanParam('DEPLOY_TO_RECETTE', true, 'Deploy to the recette machine after a successful CI.')
        booleanParam('RUN_SMOKE_TESTS', true, 'Run smoke tests on the recette machine after deployment.')
        stringParam('IMAGE_TAG', 'demo', 'Docker image tag to build and deploy.')
        stringParam('BRANCH', 'main', 'Git branch to deploy on the recette machine.')
        booleanParam('ENFORCE_QUALITY_GATE', true, 'Run the consolidated CI Quality Gate stage.')
        booleanParam('RUN_SONAR', false, 'Run SonarQube analysis.')
        stringParam('NOTIFICATION_EMAIL', 'med.yassine.bouneb@proton.me', 'Email address to notify on build failures. Leave empty to disable.')
    }
    triggers {
        githubPush()
        scm('H/5 * * * *')
        upstream('securerag-hub-ci', 'SUCCESS')
    }
    logRotator {
        numToKeep(20)
        artifactNumToKeep(20)
    }
}
