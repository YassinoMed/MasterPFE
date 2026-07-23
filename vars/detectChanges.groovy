// vars/detectChanges.groovy — SecureRAG Hub Shared Library
// Intelligent Git-based change detection engine for microservice pipeline optimization.
//
// Usage in Jenkinsfile:
//   def changes = detectChanges(targetBranch: 'origin/main')
//   if (changes.php) { ... }

def call(Map config = [:]) {
    def targetBranch = config.get('targetBranch', 'origin/main')
    def diffOutput = ""

    try {
        // Fallback to HEAD~1 if target branch isn't fetched
        diffOutput = sh(
            script: "git diff --name-only ${targetBranch}...HEAD 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo ''",
            returnStdout: true
        ).trim()
    } catch (Exception e) {
        echo "[detectChanges] Warning: Could not compute git diff. Defaulting to full execution. (${e.getMessage()})"
    }

    def files = diffOutput ? diffOutput.split('\n') : []
    echo "[detectChanges] Changed files count: ${files.size()}"

    if (files.size() > 0 && files.size() < 15) {
        echo "[detectChanges] Changed paths:\n  " + files.join("\n  ")
    }

    def changes = [
        authUsers:       files.any { it.startsWith("services-laravel/auth-users-service") },
        chatbotManager:  files.any { it.startsWith("services-laravel/chatbot-manager-service") },
        conversation:    files.any { it.startsWith("services-laravel/conversation-service") },
        auditSecurity:   files.any { it.startsWith("services-laravel/audit-security-service") },
        portalWeb:       files.any { it.startsWith("platform/portal-web") },
        extraire:        files.any { it.startsWith("services/extraire") },
        laravelAny:      files.any { it.startsWith("services-laravel/") || it.startsWith("platform/portal-web") },
        docker:          files.any { it.endsWith("Dockerfile") || it.contains("docker-compose") || it.startsWith("docker/") },
        k8s:             files.any { it.startsWith("k8s/") || it.startsWith("infra/k8s/") || it.startsWith("infra/helm/") },
        aiAgents:        files.any { it.startsWith("scripts/ai-agents/") || it.startsWith("ai-security/") || it.startsWith("scripts/ai/") },
        docsOnly:        files.size() > 0 && files.every { it.endsWith(".md") || it.startsWith("docs/") }
    ]

    // If diff computation failed or empty, run everything safety-first
    if (files.size() == 0) {
        echo "[detectChanges] Diff empty or unavailable — enabling all execution flags."
        changes.authUsers = true
        changes.chatbotManager = true
        changes.conversation = true
        changes.auditSecurity = true
        changes.portalWeb = true
        changes.extraire = true
        changes.laravelAny = true
        changes.docker = true
        changes.k8s = true
        changes.aiAgents = true
        changes.docsOnly = false
    }

    echo "[detectChanges] Matrix summary: Laravel=${changes.laravelAny}, Docker=${changes.docker}, K8s=${changes.k8s}, AI=${changes.aiAgents}, DocsOnly=${changes.docsOnly}"
    return changes
}
