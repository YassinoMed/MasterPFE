<?php

namespace Tests\Feature;

use Tests\TestCase;

class DashboardApiTest extends TestCase
{
    public function test_api_user_dashboard(): void
    {
        $this->getJson('/api/v1/portal/user-dashboard')
            ->assertOk()
            ->assertJsonStructure(['profile', 'metrics', 'chatbots']);
    }

    public function test_api_admin_dashboard(): void
    {
        $this->getJson('/api/v1/portal/admin-dashboard')
            ->assertOk()
            ->assertJsonStructure(['metrics']);
    }

    public function test_api_chatbots(): void
    {
        $this->getJson('/api/v1/portal/chatbots')
            ->assertOk()
            ->assertJsonStructure(['chatbots', 'source']);
    }

    public function test_api_users(): void
    {
        $this->getJson('/api/v1/portal/users')
            ->assertOk()
            ->assertJsonStructure(['users', 'source']);
    }

    public function test_api_roles(): void
    {
        $this->getJson('/api/v1/portal/roles')
            ->assertOk()
            ->assertJsonStructure(['roles', 'source']);
    }

    public function test_api_conversation(): void
    {
        $this->getJson('/api/v1/portal/conversation-demo')
            ->assertOk()
            ->assertJsonStructure(['conversation', 'messages', 'sources']);
    }

    public function test_api_history(): void
    {
        $this->getJson('/api/v1/portal/conversation-history')
            ->assertOk()
            ->assertJsonStructure(['history', 'source']);
    }

    public function test_api_security(): void
    {
        $this->getJson('/api/v1/portal/security-incidents')
            ->assertOk()
            ->assertJsonStructure(['summary', 'incidents']);
    }

    public function test_api_devsecops(): void
    {
        $this->getJson('/api/v1/portal/devsecops-pipeline')
            ->assertOk()
            ->assertJsonStructure(['authority', 'stages']);
    }
}
