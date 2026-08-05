<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StoreUserRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_user_validates_first_name_required(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'last_name' => 'Test',
            'email' => 'test@example.com',
            'password' => 'password123456',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['first_name']);
    }

    public function test_store_user_validates_last_name_required(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Test',
            'email' => 'test@example.com',
            'password' => 'password123456',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['last_name']);
    }

    public function test_store_user_validates_email_required(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Test',
            'last_name' => 'User',
            'password' => 'password123456',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['email']);
    }

    public function test_store_user_validates_email_format(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'not-an-email',
            'password' => 'password123456',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['email']);
    }

    public function test_store_user_validates_password_min_length(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'minpw@example.com',
            'password' => 'short',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['password']);
    }

    public function test_store_user_validates_status_values(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'status@example.com',
            'password' => 'password123456',
            'status' => 'invalid-status',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['status']);
    }

    public function test_store_user_accepts_valid_statuses(): void
    {
        foreach (['active', 'inactive', 'locked', 'pending_activation'] as $status) {
            $response = $this->postJson('/api/v1/users', [
                'first_name' => 'Test',
                'last_name' => 'User',
                'email' => "valid-{$status}@example.com",
                'password' => 'password123456',
                'status' => $status,
            ]);
            $response->assertCreated();
        }
    }

    public function test_store_user_validates_first_name_max_length(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => str_repeat('A', 101),
            'last_name' => 'User',
            'email' => 'maxname@example.com',
            'password' => 'password123456',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['first_name']);
    }

    public function test_store_user_validates_department_max_length(): void
    {
        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'dept@example.com',
            'password' => 'password123456',
            'department' => str_repeat('D', 121),
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['department']);
    }
}
