<?php

namespace Tests\Feature;

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
            'password' => 'password123456',
        ]);

        $response->assertStatus(201);
    }

    public function test_list_users(): void
    {
        $this->postJson('/api/v1/users', [
            'first_name' => 'Bob', 'last_name' => 'Test',
            'email' => 'bob@example.com', 'password' => 'password123456',
        ]);

        $response = $this->getJson('/api/v1/users');
        $response->assertStatus(200)
            ->assertJsonStructure(['data', 'meta']);
    }

    public function test_show_user(): void
    {
        $create = $this->postJson('/api/v1/users', [
            'first_name' => 'Carol', 'last_name' => 'Show',
            'email' => 'carol@example.com', 'password' => 'password123456',
        ]);
        $uuid = $create->json('data.uuid');
        $this->assertNotNull($uuid, 'User UUID should not be null. Response: ' . $create->content());

        $response = $this->getJson("/api/v1/users/{$uuid}");
        $response->assertStatus(200);
    }

    public function test_update_user(): void
    {
        $create = $this->postJson('/api/v1/users', [
            'first_name' => 'Dave', 'last_name' => 'Update',
            'email' => 'dave@example.com', 'password' => 'password123456',
        ]);
        $uuid = $create->json('data.uuid');

        $response = $this->putJson("/api/v1/users/{$uuid}", [
            'first_name' => 'David',
            'last_name' => 'Updated',
            'email' => 'david@example.com',
        ]);

        $response->assertStatus(200);
    }

    public function test_store_user_validates_email_unique(): void
    {
        $this->postJson('/api/v1/users', [
            'first_name' => 'Dup', 'last_name' => 'Email',
            'email' => 'dup@example.com', 'password' => 'password123456',
        ]);

        $response = $this->postJson('/api/v1/users', [
            'first_name' => 'Dup2', 'last_name' => 'Email2',
            'email' => 'dup@example.com', 'password' => 'password123456',
        ]);

        $response->assertStatus(422);
    }
}
