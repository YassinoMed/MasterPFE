<?php

namespace Tests\Unit;

use App\Policies\ChatbotPolicy;
use App\Models\BusinessDomain;
use App\Models\Chatbot;
use App\Models\SensitivityLevel;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotPolicyTest extends TestCase
{
    use RefreshDatabase;

    private ChatbotPolicy $policy;

    protected function setUp(): void
    {
        parent::setUp();
        $this->policy = new ChatbotPolicy();

        // Ensure foreign key dependencies exist
        BusinessDomain::query()->firstOrCreate(['name' => 'Default', 'slug' => 'default']);
        SensitivityLevel::query()->firstOrCreate(['name' => 'Public', 'slug' => 'public', 'rank' => 1]);
        User::query()->firstOrCreate([
            'first_name' => 'Test', 'last_name' => 'User',
            'email' => 'test@chatbot.test', 'password' => bcrypt('password'), 'status' => 'active',
        ]);
    }

    public function test_policy_exists(): void
    {
        $this->assertInstanceOf(ChatbotPolicy::class, $this->policy);
    }

    public function test_view_any_is_callable(): void
    {
        $user = User::first();
        $result = $this->policy->viewAny($user);
        $this->assertIsBool($result);
    }

    public function test_view_is_callable(): void
    {
        $user = User::first();
        $chatbot = Chatbot::firstOrCreate([
            'name' => 'Test Bot', 'slug' => 'test-bot' . uniqid(),
            'business_domain_id' => BusinessDomain::first()->id,
            'sensitivity_level_id' => SensitivityLevel::first()->id,
        ]);
        $result = $this->policy->view($user, $chatbot);
        $this->assertIsBool($result);
    }

    public function test_create_is_callable(): void
    {
        $user = User::first();
        $result = $this->policy->create($user);
        $this->assertIsBool($result);
    }
}
