<?php

namespace App\Services;

use App\Models\Role;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class UserDirectoryService
{
    public function list(array $filters = []): LengthAwarePaginator
    {
        return User::query()
            ->with('roles.permissions')
            ->when($filters['status'] ?? null, fn (Builder $query, string $status) => $query->where('status', $status))
            ->when($filters['department'] ?? null, fn (Builder $query, string $department) => $query->where('department', $department))
            ->when($filters['search'] ?? null, function (Builder $query, string $search): void {
                $query->where(function (Builder $inner) use ($search): void {
                    $inner
                        ->where('first_name', 'like', "%{$search}%")
                        ->orWhere('last_name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            })
            ->orderBy('last_name')
            ->paginate((int) ($filters['per_page'] ?? 25));
    }

    public function create(array $data): User
    {
        return DB::transaction(function () use ($data): User {
            $roles = $data['roles'] ?? [];
            unset($data['roles']);

            $data['password'] = Hash::make($data['password'] ?? env('AUTH_USERS_DEMO_PASSWORD', 'ChangeMe-Demo-Only'));
            $data['status'] = $data['status'] ?? 'pending_activation';

            $user = User::query()->create($data);

            if ($roles !== []) {
                $this->syncRoles($user, $roles);
            }

            return $user->load('roles.permissions');
        });
    }

    public function update(User $user, array $data): User
    {
        if (array_key_exists('password', $data) && $data['password']) {
            $data['password'] = Hash::make($data['password']);
        } else {
            unset($data['password']);
        }

        $user->fill($data);
        $user->save();

        return $user->load('roles.permissions');
    }

    public function updateStatus(User $user, string $status): User
    {
        $user->forceFill(['status' => $status])->save();

        return $user->load('roles.permissions');
    }

    public function syncRoles(User $user, array $roleNames): User
    {
        $roleIds = Role::query()
            ->whereIn('name', $roleNames)
            ->pluck('id');

        $user->roles()->sync($roleIds);

        return $user->load('roles.permissions');
    }
}
