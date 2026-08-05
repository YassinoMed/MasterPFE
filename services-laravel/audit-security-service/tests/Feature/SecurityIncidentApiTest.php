<?php

namespace Tests\Feature;

use App\Models\SecurityIncident;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SecurityIncidentApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_index_lists_incidents_with_filters(): void
    {
        SecurityIncident::create([
            'title' => 'Inc 1', 'severity' => 'high', 'status' => 'open', 'source' => 'siem',
        ]);
        SecurityIncident::create([
            'title' => 'Inc 2', 'severity' => 'low', 'status' => 'closed', 'source' => 'manual',
        ]);

        $resp = $this->getJson('/api/v1/incidents?severity=high');
        $resp->assertOk()->assertJsonCount(1, 'data');

        $resp = $this->getJson('/api/v1/incidents?status=closed');
        $resp->assertOk()->assertJsonCount(1, 'data');

        $resp = $this->getJson('/api/v1/incidents?source=siem');
        $resp->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_show_returns_incident_details(): void
    {
        $incident = SecurityIncident::create([
            'title' => 'Show Inc',
            'severity' => 'critical',
            'status' => 'open',
            'source' => 'audit',
            'description' => 'Test description',
            'detected_at' => now(),
            'resolved_at' => now(),
            'metadata' => ['key' => 'val'],
        ]);

        $this->getJson("/api/v1/incidents/{$incident->uuid}")
            ->assertOk()
            ->assertJsonPath('data.title', 'Show Inc')
            ->assertJsonPath('data.severity', 'critical')
            ->assertJsonPath('data.description', 'Test description');
    }
}
