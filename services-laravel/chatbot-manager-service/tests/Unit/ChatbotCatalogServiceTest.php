<?php

namespace Tests\Unit;

use App\Models\BusinessDomain;
use App\Models\Chatbot;
use App\Models\SensitivityLevel;
use App\Services\ChatbotCatalogService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotCatalogServiceTest extends TestCase
{
    use RefreshDatabase;

    private ChatbotCatalogService $service;

    protected function setUp(): void
    {
        parent::setUp();

        BusinessDomain::create(['name' => 'Finance', 'slug' => 'finance']);
        BusinessDomain::create(['name' => 'HR', 'slug' => 'hr']);
        SensitivityLevel::create(['name' => 'Public', 'slug' => 'public', 'rank' => 1]);
        SensitivityLevel::create(['name' => 'Internal', 'slug' => 'internal', 'rank' => 2]);

        $this->service = new ChatbotCatalogService();
    }

    public function test_domains_returns_query_builder(): void
    {
        $result = $this->service->domains()->get();
        $this->assertGreaterThanOrEqual(2, $result->count());
    }

    public function test_create_domain(): void
    {
        $domain = $this->service->createDomain([
            'name' => 'Legal',
            'slug' => 'legal',
        ]);
        $this->assertInstanceOf(BusinessDomain::class, $domain);
        $this->assertEquals('legal', $domain->slug);
        $this->assertEquals('active', $domain->status);
    }

    public function test_create_domain_with_status(): void
    {
        $domain = $this->service->createDomain([
            'name' => 'Archived',
            'slug' => 'archived',
            'status' => 'inactive',
        ]);
        $this->assertEquals('inactive', $domain->status);
    }

    public function test_update_domain(): void
    {
        $domain = BusinessDomain::where('slug', 'finance')->first();
        $updated = $this->service->updateDomain($domain, ['name' => 'Finance Updated']);
        $this->assertEquals('Finance Updated', $updated->name);
    }

    public function test_sensitivity_levels_ordered_by_rank(): void
    {
        $result = $this->service->sensitivityLevels()->get();
        $this->assertEquals('Public', $result->first()->name);
    }

    public function test_create_sensitivity_level(): void
    {
        $level = $this->service->createSensitivityLevel([
            'name' => 'Top Secret',
            'slug' => 'top-secret',
            'rank' => 5,
        ]);
        $this->assertEquals('top-secret', $level->slug);
    }

    public function test_update_sensitivity_level(): void
    {
        $level = SensitivityLevel::where('slug', 'public')->first();
        $updated = $this->service->updateSensitivityLevel($level, ['name' => 'Public Info']);
        $this->assertEquals('Public Info', $updated->name);
    }

    public function test_chatbots_filters_by_status(): void
    {
        Chatbot::create([
            'name' => 'Published Bot', 'slug' => 'pub-bot-' . uniqid(),
            'business_domain_id' => BusinessDomain::where('slug', 'finance')->first()->id,
            'sensitivity_level_id' => SensitivityLevel::where('slug', 'public')->first()->id,
            'status' => 'published',
        ]);
        Chatbot::create([
            'name' => 'Draft Bot', 'slug' => 'draft-bot-' . uniqid(),
            'business_domain_id' => BusinessDomain::where('slug', 'hr')->first()->id,
            'sensitivity_level_id' => SensitivityLevel::where('slug', 'internal')->first()->id,
            'status' => 'draft',
        ]);

        $result = $this->service->chatbots(['status' => 'published']);
        $this->assertEquals(1, $result->total());
    }

    public function test_chatbots_filters_by_domain_and_search(): void
    {
        Chatbot::create([
            'name' => 'Finance Advisor', 'slug' => 'fin-bot-' . uniqid(),
            'business_domain_id' => BusinessDomain::where('slug', 'finance')->first()->id,
            'sensitivity_level_id' => SensitivityLevel::where('slug', 'public')->first()->id,
            'status' => 'active',
        ]);
        Chatbot::create([
            'name' => 'HR Recruiter', 'slug' => 'hr-rec-' . uniqid(),
            'business_domain_id' => BusinessDomain::where('slug', 'hr')->first()->id,
            'sensitivity_level_id' => SensitivityLevel::where('slug', 'internal')->first()->id,
            'status' => 'active',
        ]);

        $byDomain = $this->service->chatbots(['domain' => 'hr']);
        $this->assertEquals(1, $byDomain->total());

        $bySearch = $this->service->chatbots(['search' => 'Advisor']);
        $this->assertEquals(1, $bySearch->total());
    }

    public function test_create_chatbot(): void
    {
        $chatbot = $this->service->createChatbot([
            'name' => 'HR Bot',
            'slug' => 'hr-bot-' . uniqid(),
            'business_domain_slug' => 'hr',
            'sensitivity_level_slug' => 'internal',
        ]);

        $this->assertInstanceOf(Chatbot::class, $chatbot);
        $this->assertEquals('draft', $chatbot->status);
        $this->assertTrue($chatbot->relationLoaded('businessDomain'));
    }

    public function test_update_chatbot_with_slug_relations(): void
    {
        $chatbot = $this->service->createChatbot([
            'name' => 'Initial Bot',
            'slug' => 'init-bot-' . uniqid(),
            'business_domain_slug' => 'hr',
            'sensitivity_level_slug' => 'internal',
        ]);

        $updated = $this->service->updateChatbot($chatbot, [
            'name' => 'Renamed Bot',
            'business_domain_slug' => 'finance',
            'sensitivity_level_slug' => 'public',
        ]);

        $this->assertEquals('Renamed Bot', $updated->name);
        $this->assertEquals('finance', $updated->businessDomain->slug);
        $this->assertEquals('public', $updated->sensitivityLevel->slug);
    }
}
