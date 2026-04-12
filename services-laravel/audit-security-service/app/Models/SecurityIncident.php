<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class SecurityIncident extends Model
{
    use HasFactory;

    public const STATUS_OPEN = 'open';
    public const STATUS_TRIAGED = 'triaged';
    public const STATUS_MITIGATED = 'mitigated';
    public const STATUS_CLOSED = 'closed';

    public const SEVERITY_LOW = 'low';
    public const SEVERITY_MEDIUM = 'medium';
    public const SEVERITY_HIGH = 'high';
    public const SEVERITY_CRITICAL = 'critical';

    protected $fillable = [
        'uuid',
        'title',
        'severity',
        'status',
        'source',
        'description',
        'detected_at',
        'resolved_at',
        'metadata',
    ];

    protected $casts = [
        'detected_at' => 'datetime',
        'resolved_at' => 'datetime',
        'metadata' => 'array',
    ];

    protected static function booted(): void
    {
        static::creating(function (SecurityIncident $incident): void {
            $incident->uuid ??= (string) Str::uuid();
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }
}
