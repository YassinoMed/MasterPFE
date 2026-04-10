def gitUrl = System.getenv('SECURERAG_GIT_URL') ?: 'https://github.com/YassinoMed/MasterPFE.git'
def branchSpec = System.getenv('SECURERAG_GIT_BRANCH') ?: '*/main'

pipelineJob('securerag-hub-cd') {
    description('SecureRAG Hub - CD pipeline (verify, promote, deploy, validate)')
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
            scriptPath('Jenkinsfile.cd')
        }
    }
    parameters {
        stringParam('REGISTRY_HOST', 'localhost:5001', 'Target OCI registry used for release and deployment.')
        stringParam('IMAGE_PREFIX', 'securerag-hub', 'Common prefix used by service images.')
        stringParam('SOURCE_IMAGE_TAG', 'dev', 'Existing signed image tag used as the release candidate.')
        stringParam('TARGET_IMAGE_TAG', 'release-local', 'Promoted image tag deployed after verification.')
        booleanParam('RUN_DEPLOY_KIND', true, 'Deploy the promoted images to the local kind cluster.')
        booleanParam('RUN_POSTDEPLOY_VALIDATION', true, 'Run post-deployment validation after deployment.')
    }
    logRotator {
        numToKeep(20)
        artifactNumToKeep(20)
    }
}
