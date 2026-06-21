<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StoreAuditLogRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_audit_log_validates_actor_reference_required(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'action' => 'login',
            'resource_type' => 'session',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['actor_reference']);
    }

    public function test_store_audit_log_validates_action_required(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'actor_reference' => 'user-123',
            'resource_type' => 'session',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['action']);
    }

    public function test_store_audit_log_validates_resource_type_required(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'actor_reference' => 'user-123',
            'action' => 'login',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['resource_type']);
    }

    public function test_store_audit_log_accepts_valid_outcome_values(): void
    {
        foreach (['success', 'failure', 'blocked'] as $outcome) {
            $response = $this->postJson('/api/v1/audit-logs', [
                'actor_reference' => 'user-123',
                'action' => 'login',
                'resource_type' => 'session',
                'outcome' => $outcome,
            ]);

            $response->assertStatus(201);
        }
    }

    public function test_store_audit_log_rejects_invalid_outcome(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'actor_reference' => 'user-123',
            'action' => 'login',
            'resource_type' => 'session',
            'outcome' => 'pending',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['outcome']);
    }

    public function test_store_audit_log_validates_ip_address_format(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'actor_reference' => 'user-123',
            'action' => 'login',
            'resource_type' => 'session',
            'ip_address' => 'invalid-ip',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['ip_address']);
    }

    public function test_store_audit_log_accepts_valid_ip(): void
    {
        $response = $this->postJson('/api/v1/audit-logs', [
            'actor_reference' => 'user-123',
            'action' => 'login',
            'resource_type' => 'session',
            'ip_address' => '192.168.1.1',
        ]);

        $response->assertStatus(201);
    }
}
