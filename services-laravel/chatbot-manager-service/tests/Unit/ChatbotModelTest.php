<?php

namespace Tests\Unit;

use App\Models\BusinessDomain;
use App\Models\Chatbot;
use App\Models\ChatbotAccessRule;
use App\Models\ChatbotPromptConfig;
use App\Models\SensitivityLevel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatbotModelTest extends TestCase
{
    use RefreshDatabase;

    private function createDomainAndLevel(): array
    {
        $domain = BusinessDomain::create(['name' => 'Legal', 'slug' => 'legal', 'status' => 'active']);
        $level = SensitivityLevel::create(['name' => 'Confidentiel', 'slug' => 'confidentiel', 'rank' => 3]);
        return [$domain, $level];
    }

    public function test_chatbot_generates_uuid(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Test Bot', 'slug' => 'test-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $this->assertNotNull($chatbot->uuid);
        $this->assertEquals(36, strlen($chatbot->uuid));
    }

    public function test_chatbot_route_key_is_uuid(): void
    {
        $this->assertEquals('uuid', (new Chatbot())->getRouteKeyName());
    }

    public function test_chatbot_casts(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Cast Bot', 'slug' => 'cast-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
            'is_active' => true, 'settings' => ['key' => 'value'],
        ]);
        $this->assertIsBool($chatbot->is_active);
        $this->assertIsArray($chatbot->settings);
    }

    public function test_chatbot_belongs_to_business_domain(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Domain Bot', 'slug' => 'domain-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $this->assertEquals($domain->id, $chatbot->businessDomain->id);
    }

    public function test_chatbot_belongs_to_sensitivity_level(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Sens Bot', 'slug' => 'sens-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $this->assertEquals($level->id, $chatbot->sensitivityLevel->id);
    }

    public function test_chatbot_has_many_prompt_configs(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Prompt Bot', 'slug' => 'prompt-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        ChatbotPromptConfig::create([
            'chatbot_id' => $chatbot->id, 'version' => 'v1',
            'system_prompt' => str_repeat('prompt text ', 5),
        ]);
        $this->assertCount(1, $chatbot->promptConfigs);
    }

    public function test_chatbot_has_many_access_rules(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Access Bot', 'slug' => 'access-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        ChatbotAccessRule::create([
            'chatbot_id' => $chatbot->id, 'rule_type' => 'role',
            'rule_payload' => ['role' => 'admin'], 'is_enabled' => true,
        ]);
        $this->assertCount(1, $chatbot->accessRules);
    }

    // ── BusinessDomain ──────────────────────────────────────────────

    public function test_business_domain_generates_uuid(): void
    {
        $domain = BusinessDomain::create(['name' => 'Test', 'slug' => 'test-dom', 'status' => 'active']);
        $this->assertNotNull($domain->uuid);
    }

    public function test_business_domain_route_key_is_uuid(): void
    {
        $this->assertEquals('uuid', (new BusinessDomain())->getRouteKeyName());
    }

    public function test_business_domain_has_many_chatbots(): void
    {
        $domain = BusinessDomain::create(['name' => 'Multi', 'slug' => 'multi', 'status' => 'active']);
        $level = SensitivityLevel::create(['name' => 'Pub', 'slug' => 'pub', 'rank' => 1]);
        Chatbot::create([
            'name' => 'Bot1', 'slug' => 'bot-1',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $this->assertCount(1, $domain->chatbots);
    }

    // ── SensitivityLevel ────────────────────────────────────────────

    public function test_sensitivity_level_generates_uuid(): void
    {
        $level = SensitivityLevel::create(['name' => 'Auto', 'slug' => 'auto-lev', 'rank' => 5]);
        $this->assertNotNull($level->uuid);
    }

    public function test_sensitivity_level_route_key_is_uuid(): void
    {
        $this->assertEquals('uuid', (new SensitivityLevel())->getRouteKeyName());
    }

    public function test_sensitivity_level_casts_rank(): void
    {
        $level = SensitivityLevel::create(['name' => 'Rank', 'slug' => 'rank-lev', 'rank' => 7]);
        $this->assertIsInt($level->rank);
    }

    public function test_sensitivity_level_has_many_chatbots(): void
    {
        $domain = BusinessDomain::create(['name' => 'Dom', 'slug' => 'dom-sl', 'status' => 'active']);
        $level = SensitivityLevel::create(['name' => 'LevBots', 'slug' => 'lev-bots', 'rank' => 9]);
        Chatbot::create([
            'name' => 'SBot', 'slug' => 's-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $this->assertCount(1, $level->chatbots);
    }

    // ── ChatbotPromptConfig ─────────────────────────────────────────

    public function test_prompt_config_generates_uuid(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'PC Bot', 'slug' => 'pc-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $config = ChatbotPromptConfig::create([
            'chatbot_id' => $chatbot->id, 'version' => 'v1',
            'system_prompt' => str_repeat('test prompt ', 5),
        ]);
        $this->assertNotNull($config->uuid);
    }

    public function test_prompt_config_belongs_to_chatbot(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Owner', 'slug' => 'owner',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $config = ChatbotPromptConfig::create([
            'chatbot_id' => $chatbot->id, 'version' => 'v1',
            'system_prompt' => str_repeat('test prompt text ', 3),
        ]);
        $this->assertEquals($chatbot->id, $config->chatbot->id);
    }

    public function test_prompt_config_casts_is_current(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Cast', 'slug' => 'cast-pc',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $config = ChatbotPromptConfig::create([
            'chatbot_id' => $chatbot->id, 'version' => 'v1',
            'system_prompt' => str_repeat('cast prompt text ', 3),
            'is_current' => true,
        ]);
        $this->assertIsBool($config->is_current);
    }

    // ── ChatbotAccessRule ───────────────────────────────────────────

    public function test_access_rule_generates_uuid(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'AR Bot', 'slug' => 'ar-bot',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $rule = ChatbotAccessRule::create([
            'chatbot_id' => $chatbot->id, 'rule_type' => 'role',
            'rule_payload' => ['role' => 'admin'], 'is_enabled' => true,
        ]);
        $this->assertNotNull($rule->uuid);
    }

    public function test_access_rule_belongs_to_chatbot(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'AR Owner', 'slug' => 'ar-owner',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $rule = ChatbotAccessRule::create([
            'chatbot_id' => $chatbot->id, 'rule_type' => 'role',
            'rule_payload' => ['role' => 'user'], 'is_enabled' => false,
        ]);
        $this->assertEquals($chatbot->id, $rule->chatbot->id);
    }

    public function test_access_rule_casts(): void
    {
        [$domain, $level] = $this->createDomainAndLevel();
        $chatbot = Chatbot::create([
            'name' => 'Cast AR', 'slug' => 'cast-ar',
            'business_domain_id' => $domain->id, 'sensitivity_level_id' => $level->id,
        ]);
        $rule = ChatbotAccessRule::create([
            'chatbot_id' => $chatbot->id, 'rule_type' => 'department',
            'rule_payload' => ['dept' => 'IT'], 'is_enabled' => true,
        ]);
        $this->assertIsArray($rule->rule_payload);
        $this->assertIsBool($rule->is_enabled);
    }
}
