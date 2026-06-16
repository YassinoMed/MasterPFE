<?php

namespace Tests\Feature;

use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserDirectoryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_user(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Alice',
            'last_name' => 'Wonder',
            'email' => 'alice@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.email', 'alice@example.com');
    }

    public function test_list_users(): void
    {
        $this->postJson('/api/v1/users', [
            'first_name' => 'Bob', 'last_name' => 'Test',
            'email' => 'bob@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response = $this->getJson('/api/v1/users');

        $response->assertStatus(200)
            ->assertJsonStructure(['data', 'meta']);
    }

    public function test_show_user(): void
    {
        $this->postJson('/api/v1/users', [
            'first_name' => 'Carol', 'last_name' => 'Show',
            'email' => 'carol@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $list = $this->getJson('/api/v1/users');
        $uuid = $list->json('data.0.uuid');

        $response = $this->getJson("/api/v1/users/{$uuid}");
        $response->assertStatus(200)
            ->assertJsonPath('data.first_name', 'Carol');
    }

    public function test_update_user(): void
    {
        $this->postJson('/api/v1/users', [
            'first_name' => 'Dave', 'last_name' => 'Update',
            'email' => 'dave@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $list = $this->getJson('/api/v1/users');
        $uuid = $list->json('data.0.uuid');

        $response = $this->putJson("/api/v1/users/{$uuid}", [
            'first_name' => 'David',
            'last_name' => 'Updated',
            'email' => 'david@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.first_name', 'David');
    }

    public function test_update_user_status(): void
    {
        $this->postJson('/api/v1/users', [
            'first_name' => 'Eve', 'last_name' => 'Status',
            'email' => 'eve@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $list = $this->getJson('/api/v1/users');
        $uuid = $list->json('data.0.uuid');

        $response = $this->patchJson("/api/v1/users/{$uuid}/status", [
            'status' => 'inactive',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.status', 'inactive');
    }

    public function test_attach_roles_to_user(): void
    {
        Role::create(['name' => 'admin', 'label' => 'Admin']);
        Role::create(['name' => 'editor', 'label' => 'Editor']);

        $this->postJson('/api/v1/users', [
            'first_name' => 'Frank', 'last_name' => 'Roles',
            'email' => 'frank@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $list = $this->getJson('/api/v1/users');
        $uuid = $list->json('data.0.uuid');

        $response = $this->postJson("/api/v1/users/{$uuid}/roles", [
            'roles' => ['admin', 'editor'],
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.roles.0.name', 'admin');
    }

    public function test_list_permissions(): void
    {
        $response = $this->getJson('/api/v1/permissions');

        $response->assertStatus(200)
            ->assertJsonStructure(['data']);
    }

    public function test_store_user_validates_email_unique(): void
    {
        $this->postJson('/api/v1/users', [
            'first_name' => 'Dup', 'last_name' => 'Email',
            'email' => 'dup@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Dup2', 'last_name' => 'Email2',
            'email' => 'dup@example.com', 'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_list_roles(): void
    {
        $response = $this->getJson('/api/v1/roles');

        $response->assertStatus(200)
            ->assertJsonStructure(['data']);
    }

    public function test_show_role(): void
    {
        Role::create(['name' => 'viewer', 'label' => 'Viewer']);
        $list = $this->getJson('/api/v1/roles');
        $uuid = $list->json('data.0.uuid');

        $response = $this->getJson("/api/v1/roles/{$uuid}");
        $response->assertStatus(200);
    }
}
