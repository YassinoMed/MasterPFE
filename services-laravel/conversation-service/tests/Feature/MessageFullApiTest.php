<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MessageFullApiTest extends TestCase
{
    use RefreshDatabase;

    protected string $convUuid;

    protected function setUp(): void
    {
        parent::setUp();

        $create = $this->postJson('/api/v1/conversations', [
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Bot',
            'user_reference' => 'user-full',
            'title' => 'Full Message Test',
        ]);

        $this->convUuid = $create->json('data.uuid');
    }

    public function test_store_message_with_citations(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->convUuid}/messages", [
            'sender' => 'assistant',
            'body' => 'Here is the answer with sources.',
            'citations' => [
                ['title' => 'Doc 1', 'confidence' => '0.95'],
                ['title' => 'Doc 2', 'confidence' => '0.87'],
            ],
        ]);

        $response->assertStatus(201);
    }

    public function test_store_message_with_safety_flags(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->convUuid}/messages", [
            'body' => 'Potentially sensitive content',
            'safety_flags' => ['pii_detected', 'toxicity_low'],
        ]);

        $response->assertStatus(201);
    }

    public function test_store_system_message(): void
    {
        $response = $this->postJson("/api/v1/conversations/{$this->convUuid}/messages", [
            'sender' => 'system',
            'body' => 'Conversation archived by admin.',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.sender', 'system');
    }

    public function test_list_messages_includes_all(): void
    {
        $this->postJson("/api/v1/conversations/{$this->convUuid}/messages", ['body' => 'Msg 1']);
        $this->postJson("/api/v1/conversations/{$this->convUuid}/messages", ['body' => 'Msg 2']);
        $this->postJson("/api/v1/conversations/{$this->convUuid}/messages", ['body' => 'Msg 3']);

        $response = $this->getJson("/api/v1/conversations/{$this->convUuid}/messages");

        $response->assertStatus(200);
        // La conversation peut avoir des messages créés par le setUp
        // ou un message système. On vérifie juste qu'il y en a au moins 3.
        $this->assertGreaterThanOrEqual(3, count($response->json('data')));
    }
}
