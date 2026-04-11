<?php

namespace Tests\Feature;

use App\Models\Chatbot;
use Database\Seeders\ChatbotCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(ChatbotCatalogSeeder::class);
    }

    public function test_it_lists_and_creates_chatbots(): void
    {
        $this->getJson('/api/v1/chatbots')
            ->assertOk()
            ->assertJsonPath('meta.total', 2)
            ->assertJsonFragment(['slug' => 'chatbot-rh']);

        $this->postJson('/api/v1/chatbots', [
            'name' => 'Chatbot Finance',
            'slug' => 'chatbot-finance',
            'description' => 'Assistant finance demo.',
            'business_domain_slug' => 'rh',
            'sensitivity_level_slug' => 'moyen',
            'status' => 'draft',
            'visibility' => 'restricted',
            'settings' => ['adapter' => 'mock', 'rag_enabled' => false],
        ])
            ->assertCreated()
            ->assertJsonPath('data.slug', 'chatbot-finance')
            ->assertJsonPath('data.business_domain.slug', 'rh');
    }

    public function test_it_updates_chatbot_status_and_roles(): void
    {
        $chatbot = Chatbot::query()->where('slug', 'chatbot-rh')->firstOrFail();

        $this->patchJson("/api/v1/chatbots/{$chatbot->uuid}/status", [
            'status' => 'disabled',
            'reason' => 'demo governance check',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'disabled')
            ->assertJsonPath('data.is_active', false);

        $this->putJson("/api/v1/chatbots/{$chatbot->uuid}/roles", [
            'roles' => [
                ['role_slug' => 'super-admin', 'is_allowed' => true],
                ['role_slug' => 'user-rh', 'is_allowed' => true],
                ['role_slug' => 'user-it', 'is_allowed' => false],
            ],
        ])
            ->assertOk()
            ->assertJsonFragment(['role_slug' => 'user-it']);

        $this->getJson("/api/v1/chatbots/{$chatbot->uuid}/roles")
            ->assertOk()
            ->assertJsonFragment(['role_slug' => 'user-rh']);
    }
}
