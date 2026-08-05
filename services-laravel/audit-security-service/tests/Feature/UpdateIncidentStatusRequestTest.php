<?php

namespace Tests\Feature;

use App\Models\SecurityIncident;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UpdateIncidentStatusRequestTest extends TestCase
{
    use RefreshDatabase;

    private string $incidentUuid;

    protected function setUp(): void
    {
        parent::setUp();
        $incident = SecurityIncident::create([
            'title' => 'Test Incident',
            'severity' => 'medium',
            'source' => 'automated',
            'status' => 'open',
        ]);
        $this->incidentUuid = $incident->uuid;
    }

    public function test_update_status_validates_required(): void
    {
        $this->patchJson("/api/v1/incidents/{$this->incidentUuid}/status", [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    public function test_update_status_validates_invalid_value(): void
    {
        $this->patchJson("/api/v1/incidents/{$this->incidentUuid}/status", ['status' => 'invalid'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['status']);
    }

    public function test_update_status_accepts_open(): void
    {
        $this->patchJson("/api/v1/incidents/{$this->incidentUuid}/status", ['status' => 'open'])
            ->assertOk();
    }

    public function test_update_status_accepts_triaged(): void
    {
        $this->patchJson("/api/v1/incidents/{$this->incidentUuid}/status", ['status' => 'triaged'])
            ->assertOk();
    }

    public function test_update_status_accepts_mitigated(): void
    {
        $this->patchJson("/api/v1/incidents/{$this->incidentUuid}/status", ['status' => 'mitigated'])
            ->assertOk();
    }

    public function test_update_status_accepts_closed(): void
    {
        $this->patchJson("/api/v1/incidents/{$this->incidentUuid}/status", ['status' => 'closed'])
            ->assertOk();
    }

    public function test_update_status_accepts_resolved_at(): void
    {
        $this->patchJson("/api/v1/incidents/{$this->incidentUuid}/status", [
            'status' => 'closed',
            'resolved_at' => '2026-06-15 14:30:00',
        ])->assertOk();
    }
}
