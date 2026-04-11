<?php

namespace Tests\Unit;

use App\Models\Chatbot;
use App\Services\ChatbotGovernanceService;
use Database\Seeders\ChatbotCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotGovernanceServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_replaces_role_access_and_tracks_current_prompt(): void
    {
        $this->seed(ChatbotCatalogSeeder::class);

        $chatbot = Chatbot::query()->where('slug', 'chatbot-rh')->firstOrFail();
        $governance = app(ChatbotGovernanceService::class);

        $roles = $governance->syncRoles($chatbot, [
            ['role_slug' => 'super-admin', 'is_allowed' => true],
            ['role_slug' => 'user-rh', 'is_allowed' => true],
        ]);

        $this->assertCount(2, $roles);

        $config = $governance->addPromptConfig($chatbot, [
            'version' => 'v2',
            'system_prompt' => 'Tu es un assistant RH demo v2 avec filtrage strict et refus des demandes hors perimetre.',
            'is_current' => true,
            'change_note' => 'Version test.',
        ]);

        $this->assertTrue($config->is_current);
        $this->assertDatabaseHas('chatbots', [
            'slug' => 'chatbot-rh',
            'system_prompt_version' => 'v2',
        ]);
    }
}
