<?php

namespace App\Services;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class RbacService
{
    public const PERMISSIONS = [
        'users.view' => ['label' => 'Voir les utilisateurs', 'domain' => 'users'],
        'users.create' => ['label' => 'Creer des utilisateurs', 'domain' => 'users'],
        'users.update' => ['label' => 'Modifier des utilisateurs', 'domain' => 'users'],
        'users.disable' => ['label' => 'Desactiver des utilisateurs', 'domain' => 'users'],
        'roles.view' => ['label' => 'Voir les roles', 'domain' => 'roles'],
        'roles.manage' => ['label' => 'Gerer les roles', 'domain' => 'roles'],
        'security.view' => ['label' => 'Voir les incidents securite', 'domain' => 'security'],
        'chatbots.view' => ['label' => 'Voir les chatbots', 'domain' => 'chatbots'],
        'chatbots.manage' => ['label' => 'Gerer les chatbots', 'domain' => 'chatbots'],
        'conversations.use.rh' => ['label' => 'Utiliser les conversations RH', 'domain' => 'conversations'],
        'conversations.use.it' => ['label' => 'Utiliser les conversations IT', 'domain' => 'conversations'],
    ];

    public const ROLES = [
        'super-admin' => [
            'label' => 'Super admin',
            'description' => 'Role complet reserve a la soutenance et aux administrateurs globaux.',
            'permissions' => [
                'users.view',
                'users.create',
                'users.update',
                'users.disable',
                'roles.view',
                'roles.manage',
                'security.view',
                'chatbots.view',
                'chatbots.manage',
                'conversations.use.rh',
                'conversations.use.it',
            ],
        ],
        'admin-plateforme' => [
            'label' => 'Admin plateforme',
            'description' => 'Administration utilisateurs, roles et chatbots.',
            'permissions' => [
                'users.view',
                'users.create',
                'users.update',
                'roles.view',
                'chatbots.view',
                'chatbots.manage',
            ],
        ],
        'admin-securite' => [
            'label' => 'Admin securite',
            'description' => 'Supervision securite et consultation RBAC.',
            'permissions' => [
                'users.view',
                'roles.view',
                'security.view',
            ],
        ],
        'user-rh' => [
            'label' => 'Utilisateur RH',
            'description' => 'Acces conversationnel limite au domaine RH.',
            'permissions' => [
                'chatbots.view',
                'conversations.use.rh',
            ],
        ],
        'user-it' => [
            'label' => 'Utilisateur IT',
            'description' => 'Acces conversationnel limite au domaine IT.',
            'permissions' => [
                'chatbots.view',
                'conversations.use.it',
            ],
        ],
    ];

    public function syncBaseline(): void
    {
        DB::transaction(function (): void {
            foreach (self::PERMISSIONS as $name => $definition) {
                Permission::query()->updateOrCreate(
                    ['name' => $name],
                    [
                        'label' => $definition['label'],
                        'domain' => $definition['domain'],
                        'description' => $definition['description'] ?? null,
                    ],
                );
            }

            foreach (self::ROLES as $name => $definition) {
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
}
