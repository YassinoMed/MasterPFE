import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm

def adminId = System.getenv("JENKINS_ADMIN_ID") ?: "admin"
def adminPassword = System.getenv("JENKINS_ADMIN_PASSWORD")

if (adminPassword) {
    def jenkins = Jenkins.get()
    def realm = jenkins.getSecurityRealm()
    if (realm instanceof HudsonPrivateSecurityRealm) {
        def user = realm.getUser(adminId)
        if (user != null) {
            user.changePassword(adminPassword)
            user.save()
            println("SecureRAG Hub Jenkins bootstrap: updated admin user password from environment.")
        } else {
            realm.createAccount(adminId, adminPassword)
            println("SecureRAG Hub Jenkins bootstrap: created admin user.")
        }
        jenkins.save()
    }
}
