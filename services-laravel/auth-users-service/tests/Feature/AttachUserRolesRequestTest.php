<?php

namespace Tests\Feature;

use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AttachUserRolesRequestTest extends TestCase
{
    use RefreshDatabase;

    protected string $userUuid;

    protected function setUp(): void
    {
        parent::setUp();

        Role::create(['name' => 'admin', 'label' => 'Admin']);
        Role::create(['name' => 'editor', 'label' => 'Editor']);

        // Create a real user via the API so we have a valid UUID
        $this->postJson('/api/v1/users', [
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'test@roles.test',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $list = $this->getJson('/api/v1/users');
        $this->userUuid = $list->json('data.0.uuid');
    }

    public function test_attach_roles_validates_roles_required(): void
    {
        $response = $this->postJson("/api/v1/users/{$this->userUuid}/roles", []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['roles']);
    }

    public function test_attach_roles_validates_roles_array(): void
    {
        $response = $this->postJson("/api/v1/users/{$this->userUuid}/roles", [
            'roles' => 'admin',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['roles']);
    }

    public function test_attach_roles_validates_roles_min_items(): void
    {
        $response = $this->postJson("/api/v1/users/{$this->userUuid}/roles", [
            'roles' => [],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['roles']);
    }

    public function test_attach_roles_validates_role_must_exist(): void
    {
        $response = $this->postJson("/api/v1/users/{$this->userUuid}/roles", [
            'roles' => ['nonexistent-role'],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['roles.0']);
    }
}
