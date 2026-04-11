<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class BusinessDomain extends Model
{
    protected $fillable = [
        'uuid',
        'name',
        'slug',
        'description',
        'status',
    ];

    protected static function booted(): void
    {
        static::creating(function (BusinessDomain $domain): void {
            if (! $domain->uuid) {
                $domain->uuid = (string) Str::uuid();
            }
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }

    public function chatbots(): HasMany
    {
        return $this->hasMany(Chatbot::class);
    }
}
