<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class SensitivityLevel extends Model
{
    protected $fillable = [
        'uuid',
        'name',
        'slug',
        'rank',
        'description',
    ];

    protected function casts(): array
    {
        return [
            'rank' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (SensitivityLevel $level): void {
            if (! $level->uuid) {
                $level->uuid = (string) Str::uuid();
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
