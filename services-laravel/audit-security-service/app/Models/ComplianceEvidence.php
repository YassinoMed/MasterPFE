<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class ComplianceEvidence extends Model
{
    use HasFactory;

    protected $table = 'compliance_evidence';

    protected $fillable = [
        'uuid',
        'control_id',
        'title',
        'status',
        'evidence_uri',
        'summary',
        'collected_at',
        'metadata',
    ];

    protected $casts = [
        'collected_at' => 'datetime',
        'metadata' => 'array',
    ];

    protected static function booted(): void
    {
        static::creating(function (ComplianceEvidence $evidence): void {
            $evidence->uuid ??= (string) Str::uuid();
            $evidence->collected_at ??= now();
        });
    }
}
