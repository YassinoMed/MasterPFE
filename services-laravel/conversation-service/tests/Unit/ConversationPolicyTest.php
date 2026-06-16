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

    public function test_policy_methods_are_callable(): void
    {
        $conversation = Conversation::firstOrCreate([
            'chatbot_slug' => 'test-bot',
            'chatbot_name' => 'Test Bot',
            'user_reference' => 'user-001',
            'title' => 'Test Conv',
        ]);

        // Tester les méthodes réellement présentes via Reflection
        $reflection = new \ReflectionClass($this->policy);
        $tested = false;
        foreach ($reflection->getMethods(\ReflectionMethod::IS_PUBLIC) as $method) {
            $name = $method->getName();
            if (in_array($name, ['before', 'view', 'create', 'update', 'delete', 'forceDelete', 'restore'])) {
                try {
                    $result = $this->policy->{$name}($conversation, $conversation);
                    $this->assertIsBool($result);
                    $tested = true;
                } catch (\ArgumentCountError $e) {
                    // skip methods with incompatible signatures
                }
            }
        }
        $this->assertTrue($tested, 'No policy methods could be tested');
    }
}
