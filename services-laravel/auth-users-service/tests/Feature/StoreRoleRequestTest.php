<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StoreRoleRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_role_validates_required_name(): void
    {
        $response = $this->postJson('/api/v1/roles', [
            'label' => 'Test Role',
            'permissions' => ['users.create'],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name']);
    }

    public function test_store_role_validates_name_format(): void
    {
        $response = $this->postJson('/api/v1/roles', [
            'name' => 'Invalid Name!',
            'label' => 'Invalid',
            'permissions' => ['users.create'],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name']);
    }

    public function test_store_role_validates_name_max_length(): void
    {
        $response = $this->postJson('/api/v1/roles', [
            'name' => str_repeat('a', 81),
            'label' => 'Too Long',
            'permissions' => ['users.create'],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['name']);
    }

    public function test_store_role_name_regex_allows_lowercase_alphanumeric_dash(): void
    {
        \App\Models\Permission::create(['name' => 'users.create', 'label' => 'Create Users', 'domain' => 'users']);

        $response = $this->postJson('/api/v1/roles', [
            'name' => 'valid-role-123',
            'label' => 'Valid',
            'permissions' => ['users.create'],
        ]);

        $response->assertStatus(201);
    }

    public function test_store_role_validates_permissions_required(): void
    {
        $response = $this->postJson('/api/v1/roles', [
            'name' => 'test-role',
            'label' => 'Test Role',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['permissions']);
    }

    public function test_store_role_validates_permissions_min_items(): void
    {
        $response = $this->postJson('/api/v1/roles', [
            'name' => 'test-role',
            'label' => 'Test Role',
            'permissions' => [],
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['permissions']);
    }
}
