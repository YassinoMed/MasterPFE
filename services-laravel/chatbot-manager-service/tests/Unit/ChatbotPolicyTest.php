<?php

namespace Tests\Unit;

use App\Models\BusinessDomain;
use App\Models\Chatbot;
use App\Models\SensitivityLevel;
use App\Models\User;
use App\Policies\BusinessDomainPolicy;
use App\Policies\ChatbotPolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotPolicyTest extends TestCase
{
    use RefreshDatabase;

    private function createChatbot(string $visibility = 'public'): Chatbot
    {
        $domain = BusinessDomain::firstOrCreate(['name' => 'Dom', 'slug' => 'dom-pol', 'status' => 'active']);
        $level = SensitivityLevel::firstOrCreate(['name' => 'Lev', 'slug' => 'lev-pol', 'rank' => 1]);
        return Chatbot::create([
            'name' => 'Pol Bot',
            'slug' => 'pol-bot-' . rand(100, 999),
            'business_domain_id' => $domain->id,
            'sensitivity_level_id' => $level->id,
            'visibility' => $visibility,
        ]);
    }

    public function test_chatbot_policy_view_any(): void
    {
        $policy = new ChatbotPolicy();
        $this->assertTrue($policy->viewAny(null));
        $this->assertTrue($policy->viewAny(new User(['email' => 'user@test.com'])));
    }

    public function test_chatbot_policy_view_public(): void
    {
        $policy = new ChatbotPolicy();
        $bot = $this->createChatbot('public');
        $this->assertTrue($policy->view(null, $bot));
    }

    public function test_chatbot_policy_view_restricted(): void
    {
        $policy = new ChatbotPolicy();
        $bot = $this->createChatbot('restricted');
        $this->assertFalse($policy->view(null, $bot));
        $this->assertTrue($policy->view(new User(['email' => 'any@test.com']), $bot));
    }

    public function test_chatbot_policy_create_admin(): void
    {
        $policy = new ChatbotPolicy();
        $admin = new User(['email' => 'admin@example.local']);
        $user = new User(['email' => 'regular@example.com']);

        $this->assertTrue($policy->create($admin));
        $this->assertFalse($policy->create($user));
    }

    public function test_chatbot_policy_update_and_change_status(): void
    {
        $policy = new ChatbotPolicy();
        $bot = $this->createChatbot();
        $admin = new User(['email' => 'admin@example.local']);
        $user = new User(['email' => 'regular@example.com']);

        $this->assertTrue($policy->update($admin, $bot));
        $this->assertFalse($policy->update($user, $bot));

        $this->assertTrue($policy->changeStatus($admin, $bot));
        $this->assertFalse($policy->changeStatus($user, $bot));
    }

    // ── BusinessDomainPolicy ────────────────────────────────────────

    public function test_business_domain_policy(): void
    {
        $policy = new BusinessDomainPolicy();
        $domain = BusinessDomain::create(['name' => 'BPol', 'slug' => 'b-pol', 'status' => 'active']);
        $admin = new User(['email' => 'admin@example.local']);
        $user = new User(['email' => 'regular@example.com']);

        $this->assertTrue($policy->viewAny(null));
        $this->assertTrue($policy->view(null, $domain));

        $this->assertTrue($policy->create($admin));
        $this->assertFalse($policy->create($user));

        $this->assertTrue($policy->update($admin, $domain));
        $this->assertFalse($policy->update($user, $domain));
    }
}
