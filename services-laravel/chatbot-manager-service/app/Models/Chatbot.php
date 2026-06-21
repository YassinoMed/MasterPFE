<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Chatbot extends Model
{
    protected $fillable = [
        'uuid',
        'name',
        'slug',
        'description',
        'business_domain_id',
        'sensitivity_level_id',
        'status',
        'visibility',
        'system_prompt_version',
        'security_profile',
        'is_active',
        'settings',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'settings' => 'array',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Chatbot $chatbot): void {
            if (! $chatbot->uuid) {
                $chatbot->uuid = (string) Str::uuid();
            }
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }

    public function businessDomain(): BelongsTo
    {
        return $this->belongsTo(BusinessDomain::class);
    }

    public function sensitivityLevel(): BelongsTo
    {
        return $this->belongsTo(SensitivityLevel::class);
    }

    public function promptConfigs(): HasMany
    {
        return $this->hasMany(ChatbotPromptConfig::class);
    }

    public function accessRules(): HasMany
    {
        return $this->hasMany(ChatbotAccessRule::class);
    }
}
