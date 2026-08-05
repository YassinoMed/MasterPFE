<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StoreComplianceEvidenceRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_validates_control_id_required(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'title' => 'Test',
            'status' => 'pass',
        ])->assertStatus(422)->assertJsonValidationErrors(['control_id']);
    }

    public function test_validates_title_required(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC1',
            'status' => 'pass',
        ])->assertStatus(422)->assertJsonValidationErrors(['title']);
    }

    public function test_validates_status_required(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC1',
            'title' => 'Test',
        ])->assertStatus(422)->assertJsonValidationErrors(['status']);
    }

    public function test_validates_status_values(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC1',
            'title' => 'Test',
            'status' => 'invalid',
        ])->assertStatus(422)->assertJsonValidationErrors(['status']);
    }

    public function test_accepts_valid_status_pass(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC1',
            'title' => 'Pass Evidence',
            'status' => 'pass',
        ])->assertCreated();
    }

    public function test_accepts_valid_status_warn(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC2',
            'title' => 'Warn Evidence',
            'status' => 'warn',
        ])->assertCreated();
    }

    public function test_accepts_valid_status_fail(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC3',
            'title' => 'Fail Evidence',
            'status' => 'fail',
        ])->assertCreated();
    }

    public function test_accepts_valid_status_not_applicable(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC4',
            'title' => 'NA Evidence',
            'status' => 'not_applicable',
        ])->assertCreated();
    }

    public function test_accepts_optional_fields(): void
    {
        $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'SOC2-CC5',
            'title' => 'Full Evidence',
            'status' => 'pass',
            'evidence_uri' => 'https://example.com/evidence',
            'summary' => 'Complete evidence with all fields',
            'collected_at' => '2026-06-15',
            'metadata' => ['reviewer' => 'auditor-1'],
        ])->assertCreated();
    }
}
