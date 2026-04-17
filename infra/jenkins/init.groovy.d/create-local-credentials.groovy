import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SecretBytes
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import hudson.util.Secret
import org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl

import java.nio.file.Files
import java.nio.file.Path

def secretsDir = Path.of('/run/jenkins-secrets')
if (!Files.isDirectory(secretsDir)) {
    println('SecureRAG Hub Jenkins bootstrap: no local secrets directory mounted, skipping credential seeding.')
    return
}

def provider = SystemCredentialsProvider.getInstance()
def store = provider.getStore()
def domain = Domain.global()

def upsertCredential = { credential, id ->
    def existing = provider.credentials.find { it.id == id }
    if (existing != null) {
        store.updateCredentials(domain, existing, credential)
        println("SecureRAG Hub Jenkins bootstrap: updated credential ${id}")
    } else {
        store.addCredentials(domain, credential)
        println("SecureRAG Hub Jenkins bootstrap: created credential ${id}")
    }
}

def privateKeyPath = secretsDir.resolve('cosign.key')
def publicKeyPath = secretsDir.resolve('cosign.pub')
def passwordPath = secretsDir.resolve('cosign.password')
def sonarTokenPath = secretsDir.resolve('sonar-token')

if (Files.exists(privateKeyPath)) {
    upsertCredential(
        new FileCredentialsImpl(
            CredentialsScope.GLOBAL,
            'cosign-private-key',
            'SecureRAG Hub local cosign private key',
            'cosign.key',
            SecretBytes.fromBytes(Files.readAllBytes(privateKeyPath))
        ),
        'cosign-private-key'
    )
}

if (Files.exists(publicKeyPath)) {
    upsertCredential(
        new FileCredentialsImpl(
            CredentialsScope.GLOBAL,
            'cosign-public-key',
            'SecureRAG Hub local cosign public key',
            'cosign.pub',
            SecretBytes.fromBytes(Files.readAllBytes(publicKeyPath))
        ),
        'cosign-public-key'
    )
}

if (Files.exists(passwordPath)) {
    upsertCredential(
        new StringCredentialsImpl(
            CredentialsScope.GLOBAL,
            'cosign-password',
            'SecureRAG Hub local cosign password',
            Secret.fromString(Files.readString(passwordPath).trim())
        ),
        'cosign-password'
    )
}

if (Files.exists(sonarTokenPath)) {
    upsertCredential(
        new StringCredentialsImpl(
            CredentialsScope.GLOBAL,
            'sonar-token',
            'SecureRAG Hub SonarQube or SonarCloud token',
            Secret.fromString(Files.readString(sonarTokenPath).trim())
        ),
        'sonar-token'
    )
}

provider.save()
