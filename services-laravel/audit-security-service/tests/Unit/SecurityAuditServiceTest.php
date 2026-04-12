<?php

namespace Tests\Unit;

use App\Models\SecurityIncident;
use App\Services\SecurityAuditService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SecurityAuditServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_service_closes_incident_with_resolution_timestamp(): void
    {
        $service = app(SecurityAuditService::class);
        $incident = $service->createIncident([
            'title' => 'Demo incident',
            'severity' => SecurityIncident::SEVERITY_MEDIUM,
            'source' => 'portal',
        ]);

        $closed = $service->updateIncidentStatus($incident, [
            'status' => SecurityIncident::STATUS_CLOSED,
        ]);

        $this->assertSame(SecurityIncident::STATUS_CLOSED, $closed->status);
        $this->assertNotNull($closed->resolved_at);
    }
}
