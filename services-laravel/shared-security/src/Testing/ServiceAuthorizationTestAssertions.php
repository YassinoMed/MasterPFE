<?php

namespace SecureRag\LaravelSecurity\Testing;

trait ServiceAuthorizationTestAssertions
{
    abstract protected function mutatingEndpoint(): string;

    protected function tearDown(): void
    {
        $this->setAuthzTestingBypass('true');
        $this->setSharedApiToken('');

        parent::tearDown();
    }

    public function test_mutating_endpoint_requires_authorization_when_testing_bypass_is_disabled(): void
    {
        $this->setAuthzTestingBypass('false');

        $this->postJson($this->mutatingEndpoint(), [])
            ->assertForbidden();
    }

    public function test_mutating_endpoint_accepts_configured_service_token(): void
    {
        $this->setAuthzTestingBypass('false');
        $this->setSharedApiToken('test-service-token');

        $this->withHeader('X-SecureRAG-Service-Token', 'test-service-token')
            ->postJson($this->mutatingEndpoint(), [])
            ->assertUnprocessable();
    }

    private function setAuthzTestingBypass(string $value): void
    {
        $_ENV['SECURERAG_AUTHZ_ALLOW_TESTING'] = $value;
        $_SERVER['SECURERAG_AUTHZ_ALLOW_TESTING'] = $value;
        putenv("SECURERAG_AUTHZ_ALLOW_TESTING={$value}");
    }

    private function setSharedApiToken(string $value): void
    {
        $_ENV['SECURERAG_SHARED_API_TOKEN'] = $value;
        $_SERVER['SECURERAG_SHARED_API_TOKEN'] = $value;
        putenv("SECURERAG_SHARED_API_TOKEN={$value}");
    }
}
