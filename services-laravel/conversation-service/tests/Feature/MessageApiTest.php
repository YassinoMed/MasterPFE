<?php

namespace Tests\Feature;

use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MessageApiTest extends TestCase
{
    use RefreshDatabase;

    protected string $conversationUuid;

    protected function setUp(): void
    {
        parent::setUp();

        $create = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'demo-chatbot',
            'chatbot_name' => 'Demo Chatbot',
            'user_reference' => 'user-001',
            'title' => 'Test Thread',
        ]);

        $this->conversationUuid = $create->json('data.uuid');
    }

    public function test_list_messages(): void
    {
        $this->postJson("/api/v1/conversations/{$this->conversationUuid}/messages", [
            'body' => 'Hello',
        ]);

        $response = $this->getJson("/api/v1/conversations/{$this->conversationUuid}/messages");

        $response->assertStatus(200)
            ->assertJsonStructure(['data']);
    }

    public function test_store_message(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->conversationUuid}/messages", [
            'body' => 'Hello, world!',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.body', 'Hello, world!');
    }

    public function test_store_message_returns_conversation_meta(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->conversationUuid}/messages", [
            'body' => 'Test message',
        ]);

        $response->assertJsonStructure([
            'data',
            'conversation' => ['uuid', 'messages_count'],
        ]);
    }
}
