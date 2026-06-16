<?php

namespace Tests\Unit;

use App\Policies\SecurityIncidentPolicy;
use App\Models\SecurityIncident;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SecurityIncidentPolicyTest extends TestCase
{
    use RefreshDatabase;

    private SecurityIncidentPolicy $policy;

    protected function setUp(): void
    {
        parent::setUp();
        $this->policy = new SecurityIncidentPolicy();
    }

    public function test_policy_exists(): void
    {
        $this->assertInstanceOf(SecurityIncidentPolicy::class, $this->policy);
    }

    public function test_policy_methods_are_callable(): void
    {
        $incident = SecurityIncident::firstOrCreate([
            'title' => 'Test Incident',
            'severity' => SecurityIncident::SEVERITY_MEDIUM,
            'source' => 'test-suite',
        ]);

        $this->assertIsBool($this->policy->viewAny($incident));
        $this->assertIsBool($this->policy->view($incident, $incident));
        $this->assertIsBool($this->policy->create($incident));
    }
}
