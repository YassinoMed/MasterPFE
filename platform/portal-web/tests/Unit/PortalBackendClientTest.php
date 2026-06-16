<?php

namespace Tests\Unit;

use App\Services\PortalBackendClient;
use Tests\TestCase;

class PortalBackendClientTest extends TestCase
{
    private PortalBackendClient $client;

    protected function setUp(): void
    {
        parent::setUp();

        config(['services.secure_rag.mode' => 'mock']);
        $this->client = new PortalBackendClient();
    }

    public function test_users_returns_array_in_mock_mode(): void
    {
        $users = $this->client->users();

        $this->assertIsArray($users);
        $this->assertNotEmpty($users);
    }

    public function test_users_entries_have_required_keys(): void
    {
        $users = $this->client->users();

        $requiredKeys = ['name', 'email', 'role', 'team', 'status', 'lastLogin'];
        foreach ($users as $user) {
            foreach ($requiredKeys as $key) {
                $this->assertArrayHasKey($key, $user, "Missing key: {$key}");
            }
        }
    }

    public function test_roles_returns_array_in_mock_mode(): void
    {
        $roles = $this->client->roles();

        $this->assertIsArray($roles);
        $this->assertNotEmpty($roles);
    }

    public function test_roles_entries_have_required_keys(): void
    {
        $roles = $this->client->roles();

        $requiredKeys = ['name', 'description', 'users', 'permissions'];
        foreach ($roles as $role) {
            foreach ($requiredKeys as $key) {
                $this->assertArrayHasKey($key, $role, "Missing key: {$key}");
            }
        }
    }

    public function test_chatbots_returns_array_in_mock_mode(): void
    {
        $chatbots = $this->client->chatbots();

        $this->assertIsArray($chatbots);
        $this->assertNotEmpty($chatbots);
    }

    public function test_conversation_returns_valid_structure_in_mock_mode(): void
    {
        $data = $this->client->conversation();

        $this->assertArrayHasKey('conversation', $data);
        $this->assertArrayHasKey('messages', $data);
        $this->assertArrayHasKey('sources', $data);
    }

    public function test_conversation_history_returns_array(): void
    {
        $history = $this->client->conversationHistory();

        $this->assertIsArray($history);
    }

    public function test_security_incidents_returns_valid_structure_in_mock_mode(): void
    {
        $data = $this->client->securityIncidents();

        $this->assertArrayHasKey('summary', $data);
        $this->assertArrayHasKey('incidents', $data);
    }

    public function test_source_returns_mock_info_before_api_call(): void
    {
        $source = $this->client->source('auth_users');

        $this->assertEquals('mock', $source['mode']);
        $this->assertEquals('mock local', $source['label']);
    }
}
