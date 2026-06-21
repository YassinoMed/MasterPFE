<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StoreMessageRequestTest extends TestCase
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

    public function test_store_message_validates_body_required(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->conversationUuid}/messages", [
            'sender' => 'user',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['body']);
    }

    public function test_store_message_validates_body_max_length(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->conversationUuid}/messages", [
            'body' => str_repeat('a', 8001),
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['body']);
    }

    public function test_store_message_creates_with_valid_data(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->conversationUuid}/messages", [
            'sender' => 'user',
            'body' => 'Hello, chatbot!',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.body', 'Hello, chatbot!');
    }

    public function test_store_message_validates_sender_enum(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->conversationUuid}/messages", [
            'sender' => 'invalid',
            'body' => 'Test message',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['sender']);
    }
}
