<?php

namespace Tests\Feature;

use App\Models\BusinessDomain;
use Database\Seeders\ChatbotCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BusinessDomainApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(ChatbotCatalogSeeder::class);
    }

    public function test_it_lists_and_creates_business_domains(): void
    {
        $this->getJson('/api/v1/business-domains')
            ->assertOk()
            ->assertJsonFragment(['slug' => 'rh'])
            ->assertJsonFragment(['slug' => 'support-it']);

        $this->postJson('/api/v1/business-domains', [
            'name' => 'Juridique',
            'slug' => 'juridique',
            'description' => 'Domaine juridique demo.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.slug', 'juridique');
    }

    public function test_it_updates_business_domain(): void
    {
        $domain = BusinessDomain::query()->where('slug', 'rh')->firstOrFail();

        $this->putJson("/api/v1/business-domains/{$domain->uuid}", [
            'name' => 'RH Groupe',
            'status' => 'inactive',
        ])
            ->assertOk()
            ->assertJsonPath('data.name', 'RH Groupe')
            ->assertJsonPath('data.status', 'inactive');
    }
}
