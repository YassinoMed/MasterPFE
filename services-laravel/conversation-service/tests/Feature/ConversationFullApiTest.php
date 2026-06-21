<?php

namespace Tests\Feature;

use App\Models\Conversation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConversationFullApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_list_conversations(): void
    {
        $response = $this->getJson('/api/v1/conversations');

        $response->assertStatus(200)
            ->assertJsonStructure(['data', 'meta']);
    }

    public function test_store_and_show_conversation(): void
    {
        $create = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'legal-assistant',
            'chatbot_name' => 'Legal Assistant',
            'user_reference' => 'user-001',
            'title' => 'Contract Review',
            'sensitivity' => 'confidential',
            'metadata' => ['department' => 'legal'],
        ]);

        $create->assertStatus(201);
        $uuid = $create->json('data.uuid');

        $show = $this->getJson("/api/v1/conversations/{$uuid}");
        $show->assertStatus(200)
            ->assertJsonPath('data.title', 'Contract Review');
    }

    public function test_store_conversation_with_status(): void
    {
        $response = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Bot',
            'user_reference' => 'user-002',
            'title' => 'Archived Chat',
            'status' => Conversation::STATUS_ARCHIVED,
        ]);

        $response->assertStatus(201);
    }

    public function test_conversation_with_initial_message(): void
    {
        $response = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'hr-bot',
            'chatbot_name' => 'HR Bot',
            'user_reference' => 'user-003',
            'title' => 'Policy Question',
            'initial_message' => 'What is the vacation policy?',
        ]);

        $response->assertStatus(201);
    }
}
