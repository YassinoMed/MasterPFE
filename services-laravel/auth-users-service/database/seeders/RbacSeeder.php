<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use App\Services\RbacService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class RbacSeeder extends Seeder
{
    public function run(RbacService $rbac): void
    {
        $rbac->syncBaseline();

        $this->seedUser(
            firstName: 'Yassine',
            lastName: 'Med',
            email: 'admin@example.local',
            department: 'Plateforme',
            jobTitle: 'Admin SecureRAG Hub',
            roles: ['super-admin'],
        );

        $this->seedUser(
            firstName: 'Nora',
            lastName: 'Audit',
            email: 'security@example.local',
            department: 'Cyber Defense',
            jobTitle: 'Security Analyst',
            roles: ['admin-securite'],
        );

        $this->seedUser(
            firstName: 'Amina',
            lastName: 'Benali',
            email: 'rh@example.local',
            department: 'RH',
            jobTitle: 'HR Business Partner',
            roles: ['user-rh'],
        );

        $this->seedUser(
            firstName: 'Karim',
            lastName: 'IT',
            email: 'it@example.local',
            department: 'IT',
            jobTitle: 'IT Support Lead',
            roles: ['user-it'],
        );
    }

    private function seedUser(
        string $firstName,
        string $lastName,
        string $email,
        string $department,
        string $jobTitle,
        array $roles,
    ): void {
        $user = User::query()->updateOrCreate(
            ['email' => $email],
            [
                'first_name' => $firstName,
                'last_name' => $lastName,
                'password' => Hash::make(env('AUTH_USERS_DEMO_PASSWORD', 'ChangeMe-Demo-Only')),
                'status' => 'active',
                'department' => $department,
                'job_title' => $jobTitle,
            ],
        );

        $roleIds = Role::query()
            ->whereIn('name', $roles)
            ->pluck('id');

        $user->roles()->sync($roleIds);
    }
}
