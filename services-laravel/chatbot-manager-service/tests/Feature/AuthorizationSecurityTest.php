<?php

namespace Tests\Feature;

use Tests\TestCase;

class AuthorizationSecurityTest extends TestCase
{
    protected function tearDown(): void
    {
        $this->setAuthzTestingBypass('true');
        $this->setSharedApiToken('');

        parent::tearDown();
    }

    public function test_mutating_chatbot_endpoint_requires_authorization_when_testing_bypass_is_disabled(): void
    {
        $this->setAuthzTestingBypass('false');

        $this->postJson('/api/v1/chatbots', [])
            ->assertForbidden();
    }

    public function test_mutating_chatbot_endpoint_accepts_configured_service_token(): void
    {
        $this->setAuthzTestingBypass('false');
        $this->setSharedApiToken('test-service-token');

        $this->withHeader('X-SecureRAG-Service-Token', 'test-service-token')
            ->postJson('/api/v1/chatbots', [])
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
