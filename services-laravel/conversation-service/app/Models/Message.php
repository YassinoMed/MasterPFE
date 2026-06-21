<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class Message extends Model
{
    use HasFactory;

    public const SENDER_USER = 'user';
    public const SENDER_ASSISTANT = 'assistant';
    public const SENDER_SYSTEM = 'system';

    protected $fillable = [
        'uuid',
        'conversation_id',
        'sender',
        'body',
        'citations',
        'safety_flags',
    ];

    protected $casts = [
        'citations' => 'array',
        'safety_flags' => 'array',
    ];

    protected static function booted(): void
    {
        static::creating(function (Message $message): void {
            $message->uuid ??= (string) Str::uuid();
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }
}
