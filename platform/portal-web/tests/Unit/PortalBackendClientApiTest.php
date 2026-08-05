<?php

namespace Tests\Unit;

use App\Services\PortalBackendClient;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PortalBackendClientApiTest extends TestCase
{
    private PortalBackendClient $client;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.secure_rag.mode' => 'api']);
        config(['services.secure_rag.auth_users.base_url' => 'http://auth-service']);
        config(['services.secure_rag.chatbot_manager.base_url' => 'http://chatbot-service']);
        config(['services.secure_rag.conversation.base_url' => 'http://conversation-service']);
        config(['services.secure_rag.audit_security.base_url' => 'http://audit-service']);
        $this->client = app(PortalBackendClient::class);
    }

    public function test_users_fetches_and_normalizes_from_api(): void
    {
        Http::fake([
            'http://auth-service/api/v1/users' => Http::response([
                'data' => [
                    [
                        'first_name' => 'John',
                        'last_name' => 'Doe',
                        'email' => 'john@test.com',
                        'roles' => [['label' => 'Admin']],
                        'department' => 'Engineering',
                        'status' => 'active',
                        'last_login_at' => '2026-06-01',
                    ],
                    [
                        'name' => 'SingleName',
                        'email' => null,
                        'roles' => ['user-role'],
                        'team' => 'Sales',
                    ],
                ],
            ]),
        ]);

        $users = $this->client->users();
        $this->assertCount(2, $users);
        $this->assertEquals('John Doe', $users[0]['name']);
        $this->assertEquals('Admin', $users[0]['role']);
        $this->assertEquals('SingleName', $users[1]['name']);
    }

    public function test_users_handles_api_failure_fallback(): void
    {
        config(['services.secure_rag.mode' => 'auto']);
        Http::fake(['http://auth-service/api/v1/users' => Http::response(null, 500)]);

        $users = $this->client->users();
        $this->assertIsArray($users);
        $this->assertEquals('mock', $this->client->source('auth_users')['mode']);
    }

    public function test_roles_fetches_and_normalizes_from_api(): void
    {
        Http::fake([
            'http://auth-service/api/v1/roles' => Http::response([
                'data' => [
                    [
                        'label' => 'Super Admin',
                        'name' => 'super-admin',
                        'description' => 'Full access',
                        'users_count' => 5,
                        'permissions' => [['name' => 'users.view'], 'security.manage'],
                    ],
                ],
            ]),
        ]);

        $roles = $this->client->roles();
        $this->assertCount(1, $roles);
        $this->assertEquals('Super Admin', $roles[0]['name']);
        $this->assertContains('users.view', $roles[0]['permissions']);
    }

    public function test_chatbots_fetches_and_normalizes_from_api(): void
    {
        Http::fake([
            'http://chatbot-service/api/v1/chatbots' => Http::response([
                'data' => [
                    [
                        'name' => 'RH Bot',
                        'business_domain' => ['name' => 'HR'],
                        'sensitivity_level' => ['name' => 'High'],
                        'status' => 'active',
                        'security_profile' => 'strict',
                        'settings' => ['owner' => 'alice', 'model_mode' => 'claude', 'temperature' => 0.5],
                    ],
                ],
            ]),
        ]);

        $chatbots = $this->client->chatbots();
        $this->assertCount(1, $chatbots);
        $this->assertEquals('RH Bot', $chatbots[0]['name']);
        $this->assertEquals('HR', $chatbots[0]['domain']);
    }

    public function test_conversation_fetches_and_normalizes_from_api(): void
    {
        Http::fake([
            'http://conversation-service/api/v1/conversations?per_page=1' => Http::response([
                'data' => [
                    ['uuid' => 'conv-123', 'title' => 'API Conv', 'chatbot_name' => 'Bot1'],
                ],
            ]),
            'http://conversation-service/api/v1/conversations/conv-123' => Http::response([
                'data' => [
                    'uuid' => 'conv-123',
                    'title' => 'API Conv Details',
                    'chatbot_name' => 'Bot1 Detailed',
                    'metadata' => ['security_status' => 'verified'],
                    'messages' => [
                        [
                            'sender' => 'user',
                            'body' => 'Hello API',
                            'created_at' => '2026-06-01T12:00:00Z',
                            'citations' => [['title' => 'Doc1', 'confidence' => 0.95]],
                        ],
                    ],
                ],
            ]),
        ]);

        $data = $this->client->conversation();
        $this->assertEquals('conv-123', $data['conversation']['id']);
        $this->assertEquals('API Conv Details', $data['conversation']['title']);
        $this->assertEquals('api', $this->client->source('conversation')['mode']);
    }

    public function test_conversation_fallback_when_empty_list(): void
    {
        config(['services.secure_rag.mode' => 'auto']);
        Http::fake([
            'http://conversation-service/api/v1/conversations?per_page=1' => Http::response(['data' => []]),
        ]);

        $data = $this->client->conversation();
        $this->assertIsArray($data);
        $this->assertEquals('mock', $this->client->source('conversation')['mode']);
    }

    public function test_conversation_history_fetches_from_api(): void
    {
        Http::fake([
            'http://conversation-service/api/v1/conversations' => Http::response([
                'data' => [
                    [
                        'uuid' => 'hist-1',
                        'title' => 'History Test',
                        'chatbot_name' => 'Bot',
                        'user_reference' => 'user-1',
                        'messages_count' => 3,
                        'metadata' => ['security_status' => 'safe'],
                        'updated_at' => '2026-06-01T14:30:00Z',
                    ],
                ],
            ]),
        ]);

        $history = $this->client->conversationHistory();
        $this->assertCount(1, $history);
        $this->assertEquals('hist-1', $history[0]['id']);
    }

    public function test_security_incidents_fetches_and_normalizes_from_api(): void
    {
        Http::fake([
            'http://audit-service/api/v1/incidents' => Http::response([
                'data' => [
                    [
                        'uuid' => 'inc-12345678-abcd',
                        'severity' => 'critical',
                        'title' => 'Data Leak Attempt',
                        'status' => 'open',
                        'source' => 'siem',
                    ],
                ],
            ]),
        ]);

        $data = $this->client->securityIncidents();
        $this->assertCount(1, $data['incidents']);
        $this->assertEquals('inc-1234', $data['incidents'][0]['id']);
        $this->assertEquals('critical', $data['incidents'][0]['severity']);
        $this->assertEquals('api', $this->client->source('audit_security')['mode']);
    }
}
