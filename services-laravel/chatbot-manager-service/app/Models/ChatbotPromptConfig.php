<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class ChatbotPromptConfig extends Model
{
    protected $fillable = [
        'uuid',
        'chatbot_id',
        'version',
        'system_prompt',
        'is_current',
        'change_note',
    ];

    protected function casts(): array
    {
        return [
            'is_current' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (ChatbotPromptConfig $config): void {
            if (! $config->uuid) {
                $config->uuid = (string) Str::uuid();
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
