<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConversationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_endpoint_is_available(): void
    {
        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertJsonPath('service', 'conversation-service');
    }

    public function test_conversation_can_be_created_and_listed(): void
    {
        $response = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'chatbot-rh',
            'chatbot_name' => 'Assistant RH',
            'domain_slug' => 'rh',
            'user_reference' => 'demo.rh@example.test',
            'user_role' => 'user-rh',
            'title' => 'Question RH',
            'initial_message' => 'Bonjour',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.chatbot_slug', 'chatbot-rh')
            ->assertJsonPath('data.messages_count', 2);

        $this->getJson('/api/v1/conversations?user_reference=demo.rh@example.test')
            ->assertOk()
            ->assertJsonPath('meta.total', 1);
    }

    public function test_message_append_can_generate_mock_answer(): void
    {
        $uuid = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'chatbot-support-it',
            'chatbot_name' => 'Assistant Support IT',
            'user_reference' => 'demo.it@example.test',
            'title' => 'Incident VPN',
        ])->json('data.uuid');

        $this->postJson("/api/v1/conversations/{$uuid}/messages", [
            'body' => 'Je ne peux pas acceder au VPN.',
        ])->assertCreated()
            ->assertJsonPath('conversation.messages_count', 2);
    }

    public function test_conversation_status_can_be_updated(): void
    {
        $uuid = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'chatbot-rh',
            'chatbot_name' => 'Assistant RH',
            'user_reference' => 'demo.rh@example.test',
            'title' => 'Cloture',
        ])->json('data.uuid');

        $this->patchJson("/api/v1/conversations/{$uuid}/status", [
            'status' => 'closed',
        ])->assertOk()
            ->assertJsonPath('data.status', 'closed');
    }
}
