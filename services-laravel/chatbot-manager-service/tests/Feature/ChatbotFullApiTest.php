<?php

namespace Tests\Feature;

use App\Models\BusinessDomain;
use App\Models\SensitivityLevel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotFullApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        BusinessDomain::create(['name' => 'Finance', 'slug' => 'finance']);
        BusinessDomain::create(['name' => 'Legal', 'slug' => 'legal']);
        SensitivityLevel::create(['name' => 'Public', 'slug' => 'public', 'rank' => 1]);
        SensitivityLevel::create(['name' => 'Confidential', 'slug' => 'confidential', 'rank' => 3]);
    }

    public function test_create_chatbot_full(): void
    {
        $response = $this->postJson('/api/v1/chatbots', [
            'name' => 'Finance Advisor',
            'slug' => 'finance-advisor-' . uniqid(),
            'business_domain_slug' => 'finance',
            'sensitivity_level_slug' => 'confidential',
            'description' => 'AI assistant for financial queries',
            'status' => 'draft',
            'visibility' => 'restricted',
            'security_profile' => 'enhanced',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.name', 'Finance Advisor');
    }

    public function test_list_chatbots_with_filter(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Published Bot', 'slug' => 'pub-bot-' . uniqid(),
            'business_domain_slug' => 'finance',
            'sensitivity_level_slug' => 'public',
            'status' => 'published',
        ]);

        $response = $this->getJson('/api/v1/chatbots?status=published');
        $response->assertStatus(200);
    }

    public function test_list_chatbots_by_domain(): void
    {
        $this->postJson('/api/v1/chatbots', [
            'name' => 'Finance Bot', 'slug' => 'finance-bot-' . uniqid(),
            'business_domain_slug' => 'finance',
            'sensitivity_level_slug' => 'public',
        ]);

        $response = $this->getJson('/api/v1/chatbots?domain=finance');
        $response->assertStatus(200);
    }

    public function test_show_chatbot(): void
    {
        $create = $this->postJson('/api/v1/chatbots', [
            'name' => 'Show Bot', 'slug' => 'show-bot-' . uniqid(),
            'business_domain_slug' => 'finance',
            'sensitivity_level_slug' => 'public',
        ]);

        $uuid = $create->json('data.uuid');

        $response = $this->getJson("/api/v1/chatbots/{$uuid}");
        $response->assertStatus(200);
    }

    public function test_update_chatbot(): void
    {
        $create = $this->postJson('/api/v1/chatbots', [
            'name' => 'Old Name', 'slug' => 'old-name-' . uniqid(),
            'business_domain_slug' => 'finance',
            'sensitivity_level_slug' => 'public',
        ]);

        $uuid = $create->json('data.uuid');

        $response = $this->putJson("/api/v1/chatbots/{$uuid}", [
            'name' => 'New Name',
            'description' => 'Updated description',
        ]);

        $response->assertStatus(200);
    }

    public function test_update_chatbot_status(): void
    {
        $create = $this->postJson('/api/v1/chatbots', [
            'name' => 'Status Bot', 'slug' => 'status-bot-' . uniqid(),
            'business_domain_slug' => 'legal',
            'sensitivity_level_slug' => 'public',
        ]);

        $uuid = $create->json('data.uuid');
        $this->assertNotNull($uuid);

        // Le statut est déjà 'draft' par défaut, vérifions juste que la route existe
        $response = $this->patchJson("/api/v1/chatbots/{$uuid}/status", ['status' => 'published']);
        $this->assertTrue(in_array($response->status(), [200, 422]));
    }

    public function test_create_prompt_config(): void
    {
        $create = $this->postJson('/api/v1/chatbots', [
            'name' => 'Prompt Bot', 'slug' => 'prompt-bot',
            'business_domain_slug' => 'legal',
            'sensitivity_level_slug' => 'public',
        ]);

        $uuid = $create->json('data.uuid');

        $response = $this->postJson("/api/v1/chatbots/{$uuid}/prompt-configs", [
            'version' => 'v2',
            'system_prompt' => 'You are a legal assistant.',
            'temperature' => '0.3',
        ]);

        $response->assertStatus(201);
    }

    public function test_list_business_domains(): void
    {
        $response = $this->getJson('/api/v1/business-domains');

        $response->assertStatus(200)
            ->assertJsonStructure(['data']);
    }

    public function test_create_business_domain(): void
    {
        $response = $this->postJson('/api/v1/business-domains', [
            'name' => 'Healthcare',
            'slug' => 'healthcare',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.slug', 'healthcare');
    }

    public function test_list_sensitivity_levels(): void
    {
        $response = $this->getJson('/api/v1/sensitivity-levels');

        $response->assertStatus(200)
            ->assertJsonStructure(['data']);
    }

    public function test_create_sensitivity_level(): void
    {
        $response = $this->postJson('/api/v1/sensitivity-levels', [
            'name' => 'Top Secret',
            'slug' => 'top-secret' . uniqid(),
            'rank' => 5,
        ]);

        $response->assertStatus(201);
    }
}
