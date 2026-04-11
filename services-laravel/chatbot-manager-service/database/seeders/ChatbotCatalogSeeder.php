<?php

namespace Database\Seeders;

use App\Models\BusinessDomain;
use App\Models\Chatbot;
use App\Models\ChatbotAccessRule;
use App\Models\ChatbotPromptConfig;
use App\Models\SensitivityLevel;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ChatbotCatalogSeeder extends Seeder
{
    public function run(): void
    {
        $rh = BusinessDomain::query()->updateOrCreate(
            ['slug' => 'rh'],
            [
                'name' => 'Ressources Humaines',
                'description' => 'Domaine demo pour politiques RH, procedures internes et support collaborateur.',
                'status' => 'active',
            ],
        );

        $supportIt = BusinessDomain::query()->updateOrCreate(
            ['slug' => 'support-it'],
            [
                'name' => 'Support IT',
                'description' => 'Domaine demo pour tickets, incidents IT et base de connaissance support.',
                'status' => 'active',
            ],
        );

        $faible = SensitivityLevel::query()->updateOrCreate(
            ['slug' => 'faible'],
            [
                'name' => 'Faible',
                'rank' => 1,
                'description' => 'Informations publiques ou peu sensibles.',
            ],
        );

        $moyen = SensitivityLevel::query()->updateOrCreate(
            ['slug' => 'moyen'],
            [
                'name' => 'Moyen',
                'rank' => 2,
                'description' => 'Informations internes necessitant un controle RBAC.',
            ],
        );

        $eleve = SensitivityLevel::query()->updateOrCreate(
            ['slug' => 'eleve'],
            [
                'name' => 'Eleve',
                'rank' => 3,
                'description' => 'Informations sensibles, acces strictement limite.',
            ],
        );

        $rhBot = $this->seedChatbot(
            domain: $rh,
            level: $eleve,
            slug: 'chatbot-rh',
            name: 'Chatbot RH',
            description: 'Assistant demo pour politiques RH et questions collaborateurs.',
            roleSlugs: ['super-admin', 'admin-plateforme', 'admin-securite', 'user-rh'],
            prompt: 'Tu es un assistant RH demo. Tu refuses toute demande hors perimetre RH et tu rappelles que les reponses doivent etre validees par les RH.',
        );

        $this->seedAccessRule($rhBot, 'pii-redaction', [
            'enabled_for' => ['messages', 'documents'],
            'action' => 'mask',
        ]);

        $itBot = $this->seedChatbot(
            domain: $supportIt,
            level: $moyen,
            slug: 'chatbot-support-it',
            name: 'Chatbot Support IT',
            description: 'Assistant demo pour aide IT, incidents support et base de connaissance.',
            roleSlugs: ['super-admin', 'admin-plateforme', 'admin-securite', 'user-it'],
            prompt: 'Tu es un assistant support IT demo. Tu proposes des etapes de diagnostic sans executer d actions systeme reelles.',
        );

        $this->seedAccessRule($itBot, 'source-required', [
            'required' => true,
            'mode' => 'demo-citation',
        ]);

        unset($faible);
    }

    private function seedChatbot(
        BusinessDomain $domain,
        SensitivityLevel $level,
        string $slug,
        string $name,
        string $description,
        array $roleSlugs,
        string $prompt,
    ): Chatbot {
        $chatbot = Chatbot::query()->updateOrCreate(
            ['slug' => $slug],
            [
                'name' => $name,
                'description' => $description,
                'business_domain_id' => $domain->id,
                'sensitivity_level_id' => $level->id,
                'status' => 'active',
                'visibility' => 'restricted',
                'system_prompt_version' => 'v1',
                'security_profile' => 'demo-guardrails',
                'is_active' => true,
                'settings' => [
                    'adapter' => 'mock',
                    'rag_enabled' => false,
                    'temperature' => 0.2,
                ],
            ],
        );

        DB::table('chatbot_role_access')->where('chatbot_id', $chatbot->id)->delete();

        foreach ($roleSlugs as $roleSlug) {
            DB::table('chatbot_role_access')->insert([
                'chatbot_id' => $chatbot->id,
                'role_slug' => $roleSlug,
                'is_allowed' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        ChatbotPromptConfig::query()->updateOrCreate(
            ['chatbot_id' => $chatbot->id, 'version' => 'v1'],
            [
                'system_prompt' => $prompt,
                'is_current' => true,
                'change_note' => 'Configuration initiale demo.',
            ],
        );

        return $chatbot;
    }

    private function seedAccessRule(Chatbot $chatbot, string $ruleType, array $payload): void
    {
        ChatbotAccessRule::query()->updateOrCreate(
            ['chatbot_id' => $chatbot->id, 'rule_type' => $ruleType],
            [
                'rule_payload' => $payload,
                'is_enabled' => true,
            ],
        );
    }
}
