<?php

namespace App\Services;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class RbacService
{
    public function syncBaseline(): void
    {
        DB::transaction(function (): void {
            foreach ($this->baselinePermissions() as $name => $definition) {
                Permission::query()->updateOrCreate(
                    ['name' => $name],
                    [
                        'label' => $definition['label'],
                        'domain' => $definition['domain'],
                        'description' => $definition['description'] ?? null,
                    ],
                );
            }

            foreach ($this->baselineRoles() as $name => $definition) {
                $role = Role::query()->updateOrCreate(
                    ['name' => $name],
                    [
                        'label' => $definition['label'],
                        'description' => $definition['description'],
                        'status' => 'active',
                    ],
                );

                $permissionIds = Permission::query()
                    ->whereIn('name', $definition['permissions'])
                    ->pluck('id');

                $role->permissions()->sync($permissionIds);
            }
        });
    }

    public function permissions(): Collection
    {
        return Permission::query()
            ->orderBy('domain')
            ->orderBy('name')
            ->get();
    }

    public function createRole(array $data): Role
    {
        return DB::transaction(function () use ($data): Role {
            $role = Role::query()->create([
                'name' => $data['name'],
                'label' => $data['label'],
                'description' => $data['description'] ?? null,
                'status' => $data['status'] ?? 'active',
            ]);

            $this->syncRolePermissions($role, $data['permissions']);

            return $role->load('permissions');
        });
    }

    public function updateRole(Role $role, array $data): Role
    {
        return DB::transaction(function () use ($role, $data): Role {
            $role->fill(collect($data)->except('permissions')->all());
            $role->save();

            if (array_key_exists('permissions', $data)) {
                $this->syncRolePermissions($role, $data['permissions']);
            }

            return $role->load('permissions');
        });
    }

    private function syncRolePermissions(Role $role, array $permissionNames): void
    {
        $permissionIds = Permission::query()
            ->whereIn('name', $permissionNames)
            ->pluck('id');

        $role->permissions()->sync($permissionIds);
    }

    private function baselinePermissions(): array
    {
        return config('rbac.permissions', []);
    }

    private function baselineRoles(): array
    {
        return config('rbac.roles', []);
    }
}
