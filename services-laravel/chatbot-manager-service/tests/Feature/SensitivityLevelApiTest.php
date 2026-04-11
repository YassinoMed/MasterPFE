<?php

namespace Tests\Feature;

use App\Models\SensitivityLevel;
use Database\Seeders\ChatbotCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SensitivityLevelApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(ChatbotCatalogSeeder::class);
    }

    public function test_it_lists_and_creates_sensitivity_levels(): void
    {
        $this->getJson('/api/v1/sensitivity-levels')
            ->assertOk()
            ->assertJsonFragment(['slug' => 'faible'])
            ->assertJsonFragment(['slug' => 'eleve']);

        $this->postJson('/api/v1/sensitivity-levels', [
            'name' => 'Critique',
            'slug' => 'critique',
            'rank' => 4,
            'description' => 'Niveau critique demo.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.slug', 'critique');
    }

    public function test_it_updates_sensitivity_level(): void
    {
        $level = SensitivityLevel::query()->where('slug', 'moyen')->firstOrFail();

        $this->putJson("/api/v1/sensitivity-levels/{$level->uuid}", [
            'name' => 'Moyen controle',
            'rank' => 5,
        ])
            ->assertOk()
            ->assertJsonPath('data.name', 'Moyen controle')
            ->assertJsonPath('data.rank', 5);
    }
}
