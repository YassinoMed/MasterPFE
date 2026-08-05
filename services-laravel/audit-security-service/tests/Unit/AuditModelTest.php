<?php

namespace Tests\Unit;

use App\Models\AuditLog;
use App\Models\ComplianceEvidence;
use App\Models\SecurityIncident;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditModelTest extends TestCase
{
    use RefreshDatabase;

    // ── AuditLog ────────────────────────────────────────────────────

    public function test_audit_log_generates_uuid(): void
    {
        $log = AuditLog::create([
            'actor_type' => 'user',
            'actor_reference' => 'user-1',
            'action' => 'login',
            'resource_type' => 'session',
        ]);
        $this->assertNotNull($log->uuid);
        $this->assertEquals(36, strlen($log->uuid));
    }

    public function test_audit_log_generates_integrity_hash(): void
    {
        $log = AuditLog::create([
            'actor_type' => 'user',
            'actor_reference' => 'user-2',
            'action' => 'create',
            'resource_type' => 'document',
        ]);
        $this->assertNotNull($log->integrity_hash);
        $this->assertEquals(64, strlen($log->integrity_hash));
    }

    public function test_audit_log_chain_links_previous_hash(): void
    {
        $log1 = AuditLog::create([
            'actor_type' => 'user',
            'actor_reference' => 'user-3',
            'action' => 'first',
            'resource_type' => 'chain',
        ]);
        $log2 = AuditLog::create([
            'actor_type' => 'user',
            'actor_reference' => 'user-3',
            'action' => 'second',
            'resource_type' => 'chain',
        ]);
        $this->assertEquals($log1->integrity_hash, $log2->previous_hash);
    }

    public function test_audit_log_sets_occurred_at_default(): void
    {
        $log = AuditLog::create([
            'actor_type' => 'system',
            'actor_reference' => 'cron',
            'action' => 'sync',
            'resource_type' => 'data',
        ]);
        $this->assertNotNull($log->occurred_at);
    }

    public function test_audit_log_casts_metadata(): void
    {
        $log = AuditLog::create([
            'actor_type' => 'user',
            'actor_reference' => 'user-4',
            'action' => 'update',
            'resource_type' => 'config',
            'metadata' => ['key' => 'value'],
        ]);
        $this->assertIsArray($log->metadata);
    }

    public function test_audit_log_casts_occurred_at(): void
    {
        $log = AuditLog::create([
            'actor_type' => 'user',
            'actor_reference' => 'user-5',
            'action' => 'view',
            'resource_type' => 'report',
            'occurred_at' => '2026-01-15 10:30:00',
        ]);
        $this->assertNotNull($log->occurred_at);
    }

    public function test_calculate_integrity_hash_is_deterministic(): void
    {
        $log = new AuditLog([
            'uuid' => 'test-uuid',
            'actor_type' => 'user',
            'actor_reference' => 'user-det',
            'action' => 'test',
            'resource_type' => 'resource',
        ]);
        $hash1 = AuditLog::calculateIntegrityHash($log);
        $hash2 = AuditLog::calculateIntegrityHash($log);
        $this->assertEquals($hash1, $hash2);
    }

    public function test_audit_log_fillable(): void
    {
        $log = new AuditLog();
        $this->assertContains('actor_type', $log->getFillable());
        $this->assertContains('actor_reference', $log->getFillable());
        $this->assertContains('action', $log->getFillable());
        $this->assertContains('resource_type', $log->getFillable());
        $this->assertContains('outcome', $log->getFillable());
        $this->assertContains('ip_address', $log->getFillable());
    }

    // ── SecurityIncident ────────────────────────────────────────────

    public function test_incident_generates_uuid(): void
    {
        $incident = SecurityIncident::create([
            'title' => 'Test Incident',
            'severity' => 'medium',
            'source' => 'automated',
            'status' => 'open',
        ]);
        $this->assertNotNull($incident->uuid);
    }

    public function test_incident_route_key_is_uuid(): void
    {
        $this->assertEquals('uuid', (new SecurityIncident())->getRouteKeyName());
    }

    public function test_incident_status_constants(): void
    {
        $this->assertEquals('open', SecurityIncident::STATUS_OPEN);
        $this->assertEquals('triaged', SecurityIncident::STATUS_TRIAGED);
        $this->assertEquals('mitigated', SecurityIncident::STATUS_MITIGATED);
        $this->assertEquals('closed', SecurityIncident::STATUS_CLOSED);
    }

    public function test_incident_severity_constants(): void
    {
        $this->assertEquals('low', SecurityIncident::SEVERITY_LOW);
        $this->assertEquals('medium', SecurityIncident::SEVERITY_MEDIUM);
        $this->assertEquals('high', SecurityIncident::SEVERITY_HIGH);
        $this->assertEquals('critical', SecurityIncident::SEVERITY_CRITICAL);
    }

    public function test_incident_casts_dates(): void
    {
        $incident = SecurityIncident::create([
            'title' => 'Dated Incident',
            'severity' => 'high',
            'source' => 'siem',
            'status' => 'open',
            'detected_at' => now(),
            'resolved_at' => now(),
        ]);
        $this->assertNotNull($incident->detected_at);
        $this->assertNotNull($incident->resolved_at);
    }

    public function test_incident_casts_metadata(): void
    {
        $incident = SecurityIncident::create([
            'title' => 'Meta Incident',
            'severity' => 'low',
            'source' => 'manual',
            'status' => 'open',
            'metadata' => ['tags' => ['test']],
        ]);
        $this->assertIsArray($incident->metadata);
    }

    // ── ComplianceEvidence ──────────────────────────────────────────

    public function test_evidence_generates_uuid(): void
    {
        $evidence = ComplianceEvidence::create([
            'control_id' => 'SOC2-CC1.1',
            'title' => 'Access Review',
            'status' => 'pass',
        ]);
        $this->assertNotNull($evidence->uuid);
    }

    public function test_evidence_sets_collected_at_default(): void
    {
        $evidence = ComplianceEvidence::create([
            'control_id' => 'SOC2-CC2.1',
            'title' => 'Log Review',
            'status' => 'pass',
        ]);
        $this->assertNotNull($evidence->collected_at);
    }

    public function test_evidence_casts_metadata(): void
    {
        $evidence = ComplianceEvidence::create([
            'control_id' => 'ISO-A.12',
            'title' => 'Backup Check',
            'status' => 'warn',
            'metadata' => ['frequency' => 'daily'],
        ]);
        $this->assertIsArray($evidence->metadata);
    }

    public function test_evidence_uses_correct_table(): void
    {
        $evidence = new ComplianceEvidence();
        $this->assertEquals('compliance_evidence', $evidence->getTable());
    }

    public function test_evidence_fillable(): void
    {
        $evidence = new ComplianceEvidence();
        $this->assertContains('control_id', $evidence->getFillable());
        $this->assertContains('title', $evidence->getFillable());
        $this->assertContains('status', $evidence->getFillable());
        $this->assertContains('evidence_uri', $evidence->getFillable());
        $this->assertContains('summary', $evidence->getFillable());
    }
}
