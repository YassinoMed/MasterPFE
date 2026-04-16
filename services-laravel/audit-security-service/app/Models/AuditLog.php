<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class AuditLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'uuid',
        'actor_type',
        'actor_reference',
        'action',
        'resource_type',
        'resource_id',
        'outcome',
        'ip_address',
        'user_agent',
        'metadata',
        'occurred_at',
    ];

    protected $casts = [
        'metadata' => 'array',
        'occurred_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::creating(function (AuditLog $auditLog): void {
            $auditLog->uuid ??= (string) Str::uuid();
            $auditLog->occurred_at ??= now();
            $auditLog->previous_hash ??= static::query()
                ->whereNotNull('integrity_hash')
                ->latest('id')
                ->value('integrity_hash');
            $auditLog->integrity_hash = static::calculateIntegrityHash($auditLog);
        });
    }

    public static function calculateIntegrityHash(self $auditLog): string
    {
        $payload = [
            'uuid' => (string) $auditLog->uuid,
            'actor_type' => (string) $auditLog->actor_type,
            'actor_reference' => (string) $auditLog->actor_reference,
            'action' => (string) $auditLog->action,
            'resource_type' => (string) $auditLog->resource_type,
            'resource_id' => $auditLog->resource_id,
            'outcome' => (string) $auditLog->outcome,
            'ip_address' => $auditLog->ip_address,
            'user_agent' => $auditLog->user_agent,
            'metadata' => $auditLog->metadata ?? [],
            'occurred_at' => $auditLog->occurred_at?->toISOString(),
            'previous_hash' => $auditLog->previous_hash,
        ];

        return hash('sha256', json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    }
}
