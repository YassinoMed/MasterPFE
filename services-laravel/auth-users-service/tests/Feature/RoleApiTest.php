<?php

namespace Tests\Feature;

use App\Models\Role;
use Database\Seeders\RbacSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RoleApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RbacSeeder::class);
    }

    public function test_it_lists_roles(): void
    {
        $this->getJson('/api/v1/roles')
            ->assertOk()
            ->assertJsonFragment(['name' => 'super-admin'])
            ->assertJsonFragment(['name' => 'admin-securite']);
    }

    public function test_it_creates_and_updates_role(): void
    {
        $response = $this->postJson('/api/v1/roles', [
            'name' => 'compliance-viewer',
            'label' => 'Compliance viewer',
            'description' => 'Read-only compliance role for demo evidence.',
            'permissions' => ['roles.view', 'security.view'],
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.name', 'compliance-viewer')
            ->assertJsonFragment(['name' => 'roles.view']);

        $role = Role::query()->where('name', 'compliance-viewer')->firstOrFail();

        $this->putJson("/api/v1/roles/{$role->uuid}", [
            'label' => 'Compliance auditor',
            'permissions' => ['roles.view', 'security.view', 'users.view'],
        ])
            ->assertOk()
            ->assertJsonPath('data.label', 'Compliance auditor');
    }
}
