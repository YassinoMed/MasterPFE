<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditSecurityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_endpoint_is_available(): void
    {
        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertJsonPath('service', 'audit-security-service');
    }

    public function test_incident_can_be_created_and_triaged(): void
    {
        $uuid = $this->postJson('/api/v1/incidents', [
            'title' => 'Policy violation demo',
            'severity' => 'high',
            'source' => 'kyverno',
            'description' => 'Image without expected metadata.',
        ])->assertCreated()
            ->assertJsonPath('data.severity', 'high')
            ->json('data.uuid');

        $this->patchJson("/api/v1/incidents/{$uuid}/status", [
            'status' => 'mitigated',
        ])->assertOk()
            ->assertJsonPath('data.status', 'mitigated');
    }

    public function test_audit_log_can_be_recorded(): void
    {
        $this->postJson('/api/v1/audit-logs', [
            'actor_reference' => 'admin@example.test',
            'action' => 'users.update',
            'resource_type' => 'user',
            'resource_id' => 'demo-user',
            'outcome' => 'success',
        ])->assertCreated()
            ->assertJsonPath('data.action', 'users.update');

        $this->getJson('/api/v1/audit-logs?resource_type=user')
            ->assertOk()
            ->assertJsonPath('meta.total', 1);
    }

    public function test_compliance_evidence_can_be_recorded(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SUPPLY-CHAIN-001',
            'title' => 'SBOM generated',
            'status' => 'pass',
            'evidence_uri' => 'artifacts/sbom/demo.spdx.json',
            'summary' => 'Demo evidence.',
        ])->assertCreated()
            ->assertJsonPath('data.control_id', 'SUPPLY-CHAIN-001');
    }
}
