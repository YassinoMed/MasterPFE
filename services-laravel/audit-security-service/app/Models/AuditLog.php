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
        });
    }
}
