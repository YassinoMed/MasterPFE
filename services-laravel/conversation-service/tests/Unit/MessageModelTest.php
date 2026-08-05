<?php

namespace Tests\Unit;

use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MessageModelTest extends TestCase
{
    use RefreshDatabase;

    private function createConversation(): Conversation
    {
        return Conversation::create([
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Bot',
            'domain_slug' => 'legal',
            'user_reference' => 'user-1',
            'title' => 'Test',
            'status' => 'open',
        ]);
    }

    public function test_message_generates_uuid(): void
    {
        $conv = $this->createConversation();
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'sender' => 'user',
            'body' => 'Hello',
        ]);
        $this->assertNotNull($msg->uuid);
        $this->assertEquals(36, strlen($msg->uuid));
    }

    public function test_message_route_key_is_uuid(): void
    {
        $this->assertEquals('uuid', (new Message())->getRouteKeyName());
    }

    public function test_message_sender_constants(): void
    {
        $this->assertEquals('user', Message::SENDER_USER);
        $this->assertEquals('assistant', Message::SENDER_ASSISTANT);
        $this->assertEquals('system', Message::SENDER_SYSTEM);
    }

    public function test_message_casts_arrays(): void
    {
        $conv = $this->createConversation();
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'sender' => 'assistant',
            'body' => 'Response',
            'citations' => [['title' => 'Source', 'confidence' => 0.9]],
            'safety_flags' => ['clean' => true],
        ]);
        $this->assertIsArray($msg->citations);
        $this->assertIsArray($msg->safety_flags);
    }

    public function test_message_belongs_to_conversation(): void
    {
        $conv = $this->createConversation();
        $msg = Message::create([
            'conversation_id' => $conv->id,
            'sender' => 'user',
            'body' => 'Hi',
        ]);
        $this->assertEquals($conv->id, $msg->conversation->id);
    }

    public function test_message_fillable(): void
    {
        $msg = new Message();
        $this->assertContains('sender', $msg->getFillable());
        $this->assertContains('body', $msg->getFillable());
        $this->assertContains('citations', $msg->getFillable());
        $this->assertContains('safety_flags', $msg->getFillable());
    }
}
