<?php

namespace Tests\Feature;

use App\Models\Conversation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UpdateConversationStatusRequestTest extends TestCase
{
    use RefreshDatabase;

    private string $conversationUuid;

    protected function setUp(): void
    {
        parent::setUp();
        $conversation = Conversation::create([
            'chatbot_slug' => 'status-bot',
            'chatbot_name' => 'Status Bot',
            'domain_slug' => 'test',
            'user_reference' => 'user-status',
            'title' => 'Status Test',
            'status' => 'open',
        ]);
        $this->conversationUuid = $conversation->uuid;
    }

    public function test_update_status_validates_required(): void
    {
        $this->patchJson("/api/v1/conversations/{$this->conversationUuid}/status", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    public function test_update_status_validates_invalid_value(): void
    {
        $this->patchJson("/api/v1/conversations/{$this->conversationUuid}/status", ['status' => 'invalid'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    public function test_update_status_accepts_open(): void
    {
        $this->patchJson("/api/v1/conversations/{$this->conversationUuid}/status", ['status' => 'open'])
            ->assertOk();
    }

    public function test_update_status_accepts_closed(): void
    {
        $this->patchJson("/api/v1/conversations/{$this->conversationUuid}/status", ['status' => 'closed'])
            ->assertOk();
    }

    public function test_update_status_accepts_archived(): void
    {
        $this->patchJson("/api/v1/conversations/{$this->conversationUuid}/status", ['status' => 'archived'])
            ->assertOk();
    }
}
