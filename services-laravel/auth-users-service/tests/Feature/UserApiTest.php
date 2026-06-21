<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\RbacSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RbacSeeder::class);
    }

    public function test_it_lists_users(): void
    {
        $this->getJson('/api/v1/users')
            ->assertOk()
            ->assertJsonPath('meta.total', 4)
            ->assertJsonPath('data.0.status', 'active');
    }

    public function test_it_creates_user_with_roles(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Salma',
            'last_name' => 'Ops',
            'email' => 'salma.ops@example.local',
            'password' => 'DemoPassword123!',
            'status' => 'active',
            'department' => 'IT',
            'job_title' => 'Platform Engineer',
            'roles' => ['admin-plateforme'],
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.email', 'salma.ops@example.local')
            ->assertJsonPath('data.roles.0.name', 'admin-plateforme');

        $this->assertDatabaseHas('users', [
            'email' => 'salma.ops@example.local',
            'status' => 'active',
        ]);
    }

    public function test_it_updates_user_status_and_roles(): void
    {
        $user = User::query()->where('email', 'rh@example.local')->firstOrFail();

        $this->patchJson("/api/v1/users/{$user->uuid}/status", [
            'status' => 'locked',
            'reason' => 'demo security control',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'locked');

        $this->postJson("/api/v1/users/{$user->uuid}/roles", [
            'roles' => ['user-it'],
        ])
            ->assertOk()
            ->assertJsonPath('data.roles.0.name', 'user-it');
    }
}
