<?php

namespace Tests\Unit;

use App\Models\Conversation;
use App\Services\ConversationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConversationServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_service_creates_conversation_with_mock_messages(): void
    {
        $conversation = app(ConversationService::class)->create([
            'chatbot_slug' => 'chatbot-rh',
            'chatbot_name' => 'Assistant RH',
            'user_reference' => 'demo@example.test',
            'title' => 'Demo',
            'initial_message' => 'Bonjour',
        ]);

        $this->assertSame(Conversation::STATUS_OPEN, $conversation->status);
        $this->assertCount(2, $conversation->messages);
    }
}
