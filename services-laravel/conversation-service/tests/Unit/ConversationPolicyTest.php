<?php

namespace Tests\Unit;

use App\Policies\ConversationPolicy;
use App\Models\Conversation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConversationPolicyTest extends TestCase
{
    use RefreshDatabase;

    private ConversationPolicy $policy;

    protected function setUp(): void
    {
        parent::setUp();
        $this->policy = new ConversationPolicy();
    }

    public function test_policy_exists(): void
    {
        $this->assertInstanceOf(ConversationPolicy::class, $this->policy);
    }

    public function test_policy_view_any_is_callable(): void
    {
        $conversation = Conversation::firstOrCreate([
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Bot',
            'user_reference' => 'user-001',
            'title' => 'Test Conv',
        ]);

        $this->assertIsBool($this->policy->viewAny($conversation));
    }

    public function test_policy_create_is_callable(): void
    {
        $conversation = Conversation::firstOrCreate([
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Bot',
            'user_reference' => 'user-001',
            'title' => 'Test Conv',
        ]);

        $this->assertIsBool($this->policy->create($conversation));
    }
}
