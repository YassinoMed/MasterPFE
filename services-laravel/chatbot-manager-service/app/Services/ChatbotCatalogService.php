<?php

namespace App\Services;

use App\Models\BusinessDomain;
use App\Models\Chatbot;
use App\Models\SensitivityLevel;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class ChatbotCatalogService
{
    public function domains(): Builder
    {
        return BusinessDomain::query()->orderBy('name');
    }

    public function createDomain(array $data): BusinessDomain
    {
        return BusinessDomain::query()->create([
            'name' => $data['name'],
            'slug' => $data['slug'],
            'description' => $data['description'] ?? null,
            'status' => $data['status'] ?? 'active',
        ]);
    }

    public function updateDomain(BusinessDomain $domain, array $data): BusinessDomain
    {
        $domain->fill($data)->save();

        return $domain;
    }

    public function sensitivityLevels(): Builder
    {
        return SensitivityLevel::query()->orderBy('rank');
    }

    public function createSensitivityLevel(array $data): SensitivityLevel
    {
        return SensitivityLevel::query()->create($data);
    }

    public function updateSensitivityLevel(SensitivityLevel $level, array $data): SensitivityLevel
    {
        $level->fill($data)->save();

        return $level;
    }

    public function chatbots(array $filters = []): LengthAwarePaginator
    {
        return Chatbot::query()
            ->with(['businessDomain', 'sensitivityLevel', 'promptConfigs', 'accessRules'])
            ->when($filters['status'] ?? null, fn (Builder $query, string $status) => $query->where('status', $status))
            ->when($filters['domain'] ?? null, function (Builder $query, string $domain): void {
                $query->whereHas('businessDomain', fn (Builder $domainQuery) => $domainQuery->where('slug', $domain));
            })
            ->when($filters['search'] ?? null, function (Builder $query, string $search): void {
                $query->where(function (Builder $inner) use ($search): void {
                    $inner
                        ->where('name', 'like', "%{$search}%")
                        ->orWhere('slug', 'like', "%{$search}%")
                        ->orWhere('description', 'like', "%{$search}%");
                });
            })
            ->orderBy('name')
            ->paginate((int) ($filters['per_page'] ?? 25));
    }

    public function createChatbot(array $data): Chatbot
    {
        return DB::transaction(function () use ($data): Chatbot {
            $domain = BusinessDomain::query()->where('slug', $data['business_domain_slug'])->firstOrFail();
            $level = SensitivityLevel::query()->where('slug', $data['sensitivity_level_slug'])->firstOrFail();

            $chatbot = Chatbot::query()->create([
                'name' => $data['name'],
                'slug' => $data['slug'],
                'description' => $data['description'] ?? null,
                'business_domain_id' => $domain->id,
                'sensitivity_level_id' => $level->id,
                'status' => $data['status'] ?? 'draft',
                'visibility' => $data['visibility'] ?? 'restricted',
                'system_prompt_version' => $data['system_prompt_version'] ?? 'v1',
                'security_profile' => $data['security_profile'] ?? 'standard',
                'is_active' => $data['is_active'] ?? false,
                'settings' => $data['settings'] ?? [],
            ]);

            return $chatbot->load(['businessDomain', 'sensitivityLevel', 'promptConfigs', 'accessRules']);
        });
    }

    public function updateChatbot(Chatbot $chatbot, array $data): Chatbot
    {
        return DB::transaction(function () use ($chatbot, $data): Chatbot {
            if (array_key_exists('business_domain_slug', $data)) {
                $data['business_domain_id'] = BusinessDomain::query()
                    ->where('slug', $data['business_domain_slug'])
                    ->firstOrFail()
                    ->id;
                unset($data['business_domain_slug']);
            }

            if (array_key_exists('sensitivity_level_slug', $data)) {
                $data['sensitivity_level_id'] = SensitivityLevel::query()
                    ->where('slug', $data['sensitivity_level_slug'])
                    ->firstOrFail()
                    ->id;
                unset($data['sensitivity_level_slug']);
            }

            $chatbot->fill($data)->save();

            return $chatbot->load(['businessDomain', 'sensitivityLevel', 'promptConfigs', 'accessRules']);
        });
    }
}
