<?php

namespace Tests\Feature;

use App\Models\Chatbot;
use Database\Seeders\ChatbotCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PromptConfigApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(ChatbotCatalogSeeder::class);
    }

    public function test_it_lists_and_creates_prompt_configs(): void
    {
        $chatbot = Chatbot::query()->where('slug', 'chatbot-support-it')->firstOrFail();

        $this->getJson("/api/v1/chatbots/{$chatbot->uuid}/prompt-configs")
            ->assertOk()
            ->assertJsonFragment(['version' => 'v1']);

        $this->postJson("/api/v1/chatbots/{$chatbot->uuid}/prompt-configs", [
            'version' => 'v2',
            'system_prompt' => 'Tu es un assistant support IT demo v2. Tu proposes des conseils sans executer d actions reelles ni demander de secrets.',
            'is_current' => true,
            'change_note' => 'Durcissement demo du prompt systeme.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.version', 'v2')
            ->assertJsonPath('data.is_current', true);

        $this->assertDatabaseHas('chatbots', [
            'slug' => 'chatbot-support-it',
            'system_prompt_version' => 'v2',
        ]);
    }
}
