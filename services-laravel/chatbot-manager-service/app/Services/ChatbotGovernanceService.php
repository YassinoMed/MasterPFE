<?php

namespace App\Services;

use App\Models\Chatbot;
use App\Models\ChatbotPromptConfig;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class ChatbotGovernanceService
{
    public const ALLOWED_ROLE_SLUGS = [
        'super-admin',
        'admin-plateforme',
        'admin-securite',
        'user-rh',
        'user-it',
    ];

    public function updateStatus(Chatbot $chatbot, string $status, ?bool $isActive = null): Chatbot
    {
        $chatbot->forceFill([
            'status' => $status,
            'is_active' => $isActive ?? $status === 'active',
        ])->save();

        return $chatbot->load(['businessDomain', 'sensitivityLevel', 'promptConfigs', 'accessRules']);
    }

    public function roles(Chatbot $chatbot): Collection
    {
        return DB::table('chatbot_role_access')
            ->where('chatbot_id', $chatbot->id)
            ->orderBy('role_slug')
            ->get(['role_slug', 'is_allowed']);
    }

    public function syncRoles(Chatbot $chatbot, array $roles): Collection
    {
        return DB::transaction(function () use ($chatbot, $roles): Collection {
            DB::table('chatbot_role_access')->where('chatbot_id', $chatbot->id)->delete();

            foreach ($roles as $role) {
                DB::table('chatbot_role_access')->insert([
                    'chatbot_id' => $chatbot->id,
                    'role_slug' => $role['role_slug'],
                    'is_allowed' => $role['is_allowed'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            return $this->roles($chatbot);
        });
    }

    public function addPromptConfig(Chatbot $chatbot, array $data): ChatbotPromptConfig
    {
        return DB::transaction(function () use ($chatbot, $data): ChatbotPromptConfig {
            $isCurrent = $data['is_current'] ?? ! $chatbot->promptConfigs()->where('is_current', true)->exists();

            if ($isCurrent) {
                $chatbot->promptConfigs()->update(['is_current' => false]);
                $chatbot->forceFill(['system_prompt_version' => $data['version']])->save();
            }

            return $chatbot->promptConfigs()->create([
                'version' => $data['version'],
                'system_prompt' => $data['system_prompt'],
                'is_current' => $isCurrent,
                'change_note' => $data['change_note'] ?? null,
            ]);
        });
    }
}
