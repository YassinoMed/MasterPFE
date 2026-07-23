// vars/aiStageRunner.groovy — SecureRAG Hub Shared Library
// Helper to evaluate and run AI agents only when relevant code/manifest changes occur.
//
// Usage in Jenkinsfile:
//   aiStageRunner(stageName: 'docker-audit', changes: changes)

def call(Map config = [:]) {
    def stageName = config.get('stageName')
    def changes = config.get('changes', [:])
    def forceRun = config.get('forceRun', false)

    if (!stageName) {
        error "[aiStageRunner] Missing required argument 'stageName'"
    }

    def shouldRun = forceRun

    switch (stageName) {
        case 'planning':
        case 'threat-modeling':
        case 'consensus':
        case 'risk-analysis':
            // High-level AI governance runs on PRs or full builds
            shouldRun = forceRun || changes.get('laravelAny', true) || changes.get('docker', true) || changes.get('k8s', true)
            break
        case 'docker-audit':
            shouldRun = forceRun || changes.get('docker', false)
            break
        case 'kubernetes-audit':
            shouldRun = forceRun || changes.get('k8s', false)
            break
        case 'code-review':
            shouldRun = forceRun || changes.get('laravelAny', false) || changes.get('aiAgents', false)
            break
        case 'security-testing':
            shouldRun = forceRun || changes.get('laravelAny', false)
            break
        default:
            shouldRun = forceRun
            break
    }

    if (!shouldRun) {
        echo "[aiStageRunner] Skipping AI Stage '${stageName}' (No relevant changes detected)."
        return false
    }

    echo "[aiStageRunner] Executing AI Stage '${stageName}'..."
    return true
}
