<?php

namespace Tests\Unit;

use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConversationModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_conversation_generates_uuid(): void
    {
        $conv = Conversation::create([
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Bot',
            'domain_slug' => 'legal',
            'user_reference' => 'user-1',
            'title' => 'Test',
            'status' => 'open',
        ]);
        $this->assertNotNull($conv->uuid);
        $this->assertEquals(36, strlen($conv->uuid));
    }

    public function test_conversation_route_key_is_uuid(): void
    {
        $this->assertEquals('uuid', (new Conversation())->getRouteKeyName());
    }

    public function test_conversation_status_constants(): void
    {
        $this->assertEquals('open', Conversation::STATUS_OPEN);
        $this->assertEquals('closed', Conversation::STATUS_CLOSED);
        $this->assertEquals('archived', Conversation::STATUS_ARCHIVED);
    }

    public function test_conversation_casts_metadata(): void
    {
        $conv = Conversation::create([
            'chatbot_slug' => 'cast-bot',
            'chatbot_name' => 'Cast Bot',
            'domain_slug' => 'hr',
            'user_reference' => 'user-2',
            'title' => 'Cast Test',
            'status' => 'open',
            'metadata' => ['key' => 'value'],
        ]);
        $this->assertIsArray($conv->metadata);
    }

    public function test_conversation_has_many_messages(): void
    {
        $conv = Conversation::create([
            'chatbot_slug' => 'msg-bot',
            'chatbot_name' => 'Msg Bot',
            'domain_slug' => 'it',
            'user_reference' => 'user-3',
            'title' => 'Messages Test',
            'status' => 'open',
        ]);
        Message::create([
            'conversation_id' => $conv->id,
            'sender' => 'user',
            'body' => 'Hello',
        ]);
        $this->assertCount(1, $conv->messages);
    }

    public function test_conversation_fillable(): void
    {
        $conv = new Conversation();
        $this->assertContains('chatbot_slug', $conv->getFillable());
        $this->assertContains('user_reference', $conv->getFillable());
        $this->assertContains('title', $conv->getFillable());
        $this->assertContains('status', $conv->getFillable());
        $this->assertContains('sensitivity', $conv->getFillable());
    }
}
