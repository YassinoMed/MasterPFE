<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditLogApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_list_audit_logs(): void
    {
        $response = $this->getJson('/api/v1/audit-logs');

        $response->assertStatus(200)
            ->assertJsonStructure(['data', 'meta']);
    }

    public function test_store_audit_log(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'actor_reference' => 'user-001',
            'action' => 'login',
            'resource_type' => 'session',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.action', 'login');
    }

    public function test_store_audit_log_with_all_fields(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'actor_type' => 'user',
            'actor_reference' => 'user-002',
            'action' => 'api.access',
            'resource_type' => 'endpoint',
            'resource_id' => 'GET:/api/v1/users',
            'outcome' => 'success',
            'ip_address' => '10.0.0.1',
            'metadata' => ['key' => 'value'],
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.outcome', 'success');
    }
}
