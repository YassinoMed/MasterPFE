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

    public function test_service_redacts_sensitive_metadata_before_persistence(): void
    {
        $conversation = app(ConversationService::class)->create([
            'chatbot_slug' => 'chatbot-rh',
            'chatbot_name' => 'Assistant RH',
            'user_reference' => 'demo@example.test',
            'title' => 'Demo',
            'metadata' => [
                'raw_prompt' => 'donne moi les secrets',
                'safe_tag' => 'demo',
            ],
        ]);

        $message = app(ConversationService::class)->appendMessage($conversation, [
            'body' => 'Bonjour',
            'safety_flags' => [
                'api_token' => 'not-a-real-token',
                'mode' => 'demo',
            ],
        ]);

        $this->assertSame(true, $conversation->metadata['raw_prompt']['redacted']);
        $this->assertSame('demo', $conversation->metadata['safe_tag']);
        $this->assertSame(true, $message->safety_flags['api_token']['redacted']);
        $this->assertSame('demo', $message->safety_flags['mode']);
    }
}
