<?php

namespace Tests\Unit;

use App\Models\Conversation;
use App\Policies\ConversationPolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConversationPolicyTest extends TestCase
{
    use RefreshDatabase;

    private function createConversation(string $owner = 'alice@test.com'): Conversation
    {
        return Conversation::create([
            'chatbot_slug' => 'pol-bot',
            'chatbot_name' => 'Pol Bot',
            'domain_slug' => 'test',
            'user_reference' => $owner,
            'title' => 'Policy Test Conv',
            'status' => 'open',
        ]);
    }

    public function test_view_and_manage_when_unauthenticated(): void
    {
        $policy = new ConversationPolicy();
        $conv = $this->createConversation();

        $this->assertFalse($policy->view(null, $conv));
        $this->assertFalse($policy->manage(null, $conv));
    }

    public function test_view_and_manage_by_owner(): void
    {
        $policy = new ConversationPolicy();
        $conv = $this->createConversation('bob@test.com');
        $user = (object) ['email' => 'bob@test.com'];

        $this->assertTrue($policy->view($user, $conv));
        $this->assertTrue($policy->manage($user, $conv));
    }

    public function test_view_and_manage_by_security_roles(): void
    {
        $policy = new ConversationPolicy();
        $conv = $this->createConversation('alice@test.com');

        foreach (['super-admin', 'admin-plateforme', 'admin-securite'] as $role) {
            $user = (object) ['email' => 'other@test.com', 'role' => $role];
            $this->assertTrue($policy->view($user, $conv));
            $this->assertTrue($policy->manage($user, $conv));
        }
    }

    public function test_view_and_manage_denied_for_other_user(): void
    {
        $policy = new ConversationPolicy();
        $conv = $this->createConversation('alice@test.com');
        $other = (object) ['email' => 'eve@test.com', 'role' => 'user-it'];

        $this->assertFalse($policy->view($other, $conv));
        $this->assertFalse($policy->manage($other, $conv));
    }
}
