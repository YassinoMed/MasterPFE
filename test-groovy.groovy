import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm
def adminPassword = "test"
def adminId = "admin"
def jenkins = Jenkins.get()
def realm = jenkins.getSecurityRealm()
if (realm instanceof HudsonPrivateSecurityRealm) {
    def user = hudson.model.User.getById(adminId, false)
    if (user != null) {
        def details = hudson.security.HudsonPrivateSecurityRealm.Details.fromPlainPassword(adminPassword)
        user.addProperty(details)
        user.save()
        println("updated")
    }
}
