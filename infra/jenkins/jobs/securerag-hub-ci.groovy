def gitUrl = System.getenv('SECURERAG_GIT_URL') ?: 'https://github.com/YassinoMed/MasterPFE.git'
def branchSpec = System.getenv('SECURERAG_GIT_BRANCH') ?: '*/main'

pipelineJob('securerag-hub-ci') {
    description('SecureRAG Hub - CI pipeline (lint, tests, coverage, security scans)')
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
            scriptPath('Jenkinsfile')
        }
    }
    triggers {
        scm('H/5 * * * *')
    }
    logRotator {
        numToKeep(20)
        artifactNumToKeep(20)
    }
}
