<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StoreConversationRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_conversation_validates_chatbot_slug_required(): void
    {
        $response = $this->postJson('/api/v1/conversations', [
            'chatbot_name' => 'Test Chatbot',
            'user_reference' => 'user-001',
            'title' => 'Test Conversation',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['chatbot_slug']);
    }

    public function test_store_conversation_validates_title_required(): void
    {
        $response = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Chatbot',
            'user_reference' => 'user-001',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['title']);
    }

    public function test_store_conversation_validates_user_reference_required(): void
    {
        $response = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Chatbot',
            'title' => 'Test',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['user_reference']);
    }

    public function test_store_conversation_creates_with_valid_data(): void
    {
        $response = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'demo-chatbot',
            'chatbot_name' => 'Demo Chatbot',
            'user_reference' => 'user-001',
            'title' => 'My Conversation',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.title', 'My Conversation');
    }
}
