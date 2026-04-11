<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Support\Str;

class Permission extends Model
{
    protected $fillable = [
        'uuid',
        'name',
        'label',
        'domain',
        'description',
    ];

    protected static function booted(): void
    {
        static::creating(function (Permission $permission): void {
            if (! $permission->uuid) {
                $permission->uuid = (string) Str::uuid();
            }
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class)->withTimestamps();
    }
}
