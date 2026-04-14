<?php

namespace Tests\Feature;

use Tests\TestCase;

class AuthorizationSecurityTest extends TestCase
{
    protected function tearDown(): void
    {
        $this->setAuthzTestingBypass('true');

        parent::tearDown();
    }

    public function test_mutating_conversation_endpoint_requires_authorization_when_testing_bypass_is_disabled(): void
    {
        $this->setAuthzTestingBypass('false');

        $this->postJson('/api/v1/conversations', [])
            ->assertForbidden();
    }

    private function setAuthzTestingBypass(string $value): void
    {
        $_ENV['SECURERAG_AUTHZ_ALLOW_TESTING'] = $value;
        $_SERVER['SECURERAG_AUTHZ_ALLOW_TESTING'] = $value;
        putenv("SECURERAG_AUTHZ_ALLOW_TESTING={$value}");
    }
}
