<?php

namespace Tests\Feature;

use App\Models\BusinessDomain;
use App\Models\SensitivityLevel;
use Database\Seeders\ChatbotCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotValidationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(ChatbotCatalogSeeder::class);
    }

    // ── StoreChatbotRequest ─────────────────────────────────────────

    public function test_store_chatbot_validates_name_required(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'slug' => 'test',
            'business_domain_slug' => 'rh',
            'sensitivity_level_slug' => 'eleve',
        ])->assertStatus(422)->assertJsonValidationErrors(['name']);
    }

    public function test_store_chatbot_validates_slug_required(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Test',
            'business_domain_slug' => 'rh',
            'sensitivity_level_slug' => 'eleve',
        ])->assertStatus(422)->assertJsonValidationErrors(['slug']);
    }

    public function test_store_chatbot_validates_slug_format(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Test', 'slug' => 'Invalid Slug!',
            'business_domain_slug' => 'rh',
            'sensitivity_level_slug' => 'eleve',
        ])->assertStatus(422)->assertJsonValidationErrors(['slug']);
    }

    public function test_store_chatbot_validates_business_domain_exists(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Test', 'slug' => 'test-val',
            'business_domain_slug' => 'nonexistent',
            'sensitivity_level_slug' => 'eleve',
        ])->assertStatus(422)->assertJsonValidationErrors(['business_domain_slug']);
    }

    public function test_store_chatbot_validates_sensitivity_level_exists(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Test', 'slug' => 'test-val2',
            'business_domain_slug' => 'rh',
            'sensitivity_level_slug' => 'nonexistent',
        ])->assertStatus(422)->assertJsonValidationErrors(['sensitivity_level_slug']);
    }

    public function test_store_chatbot_validates_status_values(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Test', 'slug' => 'test-val3',
            'business_domain_slug' => 'rh',
            'sensitivity_level_slug' => 'eleve',
            'status' => 'invalid',
        ])->assertStatus(422)->assertJsonValidationErrors(['status']);
    }

    public function test_store_chatbot_validates_visibility_values(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Test', 'slug' => 'test-val4',
            'business_domain_slug' => 'rh',
            'sensitivity_level_slug' => 'eleve',
            'visibility' => 'invalid',
        ])->assertStatus(422)->assertJsonValidationErrors(['visibility']);
    }

    // ── UpdateChatbotStatusRequest ──────────────────────────────────

    public function test_update_status_validates_required(): void
    {
        $chatbots = $this->getJson('/api/v1/chatbots')->json('data');
        $uuid = $chatbots[0]['uuid'] ?? 'missing';

        $this->patchJson("/api/v1/chatbots/{$uuid}/status", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    public function test_update_status_validates_values(): void
    {
        $chatbots = $this->getJson('/api/v1/chatbots')->json('data');
        $uuid = $chatbots[0]['uuid'] ?? 'missing';

        $this->patchJson("/api/v1/chatbots/{$uuid}/status", ['status' => 'invalid'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    public function test_update_status_accepts_valid_values(): void
    {
        $chatbots = $this->getJson('/api/v1/chatbots')->json('data');
        $uuid = $chatbots[0]['uuid'] ?? 'missing';

        foreach (['draft', 'active', 'disabled', 'archived'] as $status) {
            $this->patchJson("/api/v1/chatbots/{$uuid}/status", ['status' => $status])
                ->assertOk();
        }
    }

    // ── StorePromptConfigRequest ────────────────────────────────────

    public function test_store_prompt_config_validates_version_required(): void
    {
        $chatbots = $this->getJson('/api/v1/chatbots')->json('data');
        $uuid = $chatbots[0]['uuid'] ?? 'missing';

        $this->postJson("/api/v1/chatbots/{$uuid}/prompt-configs", [
            'system_prompt' => str_repeat('a valid prompt text ', 3),
        ])->assertStatus(422)->assertJsonValidationErrors(['version']);
    }

    public function test_store_prompt_config_validates_prompt_min_length(): void
    {
        $chatbots = $this->getJson('/api/v1/chatbots')->json('data');
        $uuid = $chatbots[0]['uuid'] ?? 'missing';

        $this->postJson("/api/v1/chatbots/{$uuid}/prompt-configs", [
            'version' => 'v1',
            'system_prompt' => 'too short',
        ])->assertStatus(422)->assertJsonValidationErrors(['system_prompt']);
    }

    // ── StoreSensitivityLevelRequest ────────────────────────────────

    public function test_store_sensitivity_level_validates_name_required(): void
    {
        $this->postJson('/api/v1/sensitivity-levels', [
            'slug' => 'test-lev', 'rank' => 10,
        ])->assertStatus(422)->assertJsonValidationErrors(['name']);
    }

    public function test_store_sensitivity_level_validates_slug_unique(): void
    {
        $this->postJson('/api/v1/sensitivity-levels', [
            'name' => 'Duplicate', 'slug' => 'faible', 'rank' => 50,
        ])->assertStatus(422)->assertJsonValidationErrors(['slug']);
    }

    public function test_store_sensitivity_level_validates_rank_range(): void
    {
        $this->postJson('/api/v1/sensitivity-levels', [
            'name' => 'OutOfRange', 'slug' => 'oor', 'rank' => 100,
        ])->assertStatus(422)->assertJsonValidationErrors(['rank']);
    }

    // ── StoreBusinessDomainRequest ──────────────────────────────────

    public function test_store_business_domain_validates_name_required(): void
    {
        $this->postJson('/api/v1/business-domains', [
            'slug' => 'test-dom',
        ])->assertStatus(422)->assertJsonValidationErrors(['name']);
    }

    public function test_store_business_domain_validates_slug_unique(): void
    {
        $this->postJson('/api/v1/business-domains', [
            'name' => 'Duplicate', 'slug' => 'rh',
        ])->assertStatus(422)->assertJsonValidationErrors(['slug']);
    }

    public function test_store_business_domain_validates_status_values(): void
    {
        $this->postJson('/api/v1/business-domains', [
            'name' => 'Bad Status', 'slug' => 'bad-status', 'status' => 'invalid',
        ])->assertStatus(422)->assertJsonValidationErrors(['status']);
    }
}
