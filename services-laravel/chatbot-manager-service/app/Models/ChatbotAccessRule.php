<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class ChatbotAccessRule extends Model
{
    protected $fillable = [
        'uuid',
        'chatbot_id',
        'rule_type',
        'rule_payload',
        'is_enabled',
    ];

    protected function casts(): array
    {
        return [
            'rule_payload' => 'array',
            'is_enabled' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (ChatbotAccessRule $rule): void {
            if (! $rule->uuid) {
                $rule->uuid = (string) Str::uuid();
            }
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }

    public function chatbot(): BelongsTo
    {
        return $this->belongsTo(Chatbot::class);
    }
}
