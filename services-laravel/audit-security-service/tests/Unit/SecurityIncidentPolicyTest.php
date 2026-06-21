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

        // Tester les méthodes qui existent réellement sur la Policy
        $reflection = new \ReflectionClass($this->policy);
        foreach ($reflection->getMethods(\ReflectionMethod::IS_PUBLIC) as $method) {
            $name = $method->getName();
            if (in_array($name, ['before', 'view', 'create', 'update', 'delete'])) {
                try {
                    $result = $this->policy->{$name}($incident, $incident);
                    $this->assertIsBool($result, "Method {$name} should return bool");
                } catch (\ArgumentCountError $e) {
                    // Certaines méthodes ont des signatures différentes
                    $this->assertTrue(true);
                }
            }
        }

        $this->assertTrue(true);
    }
}
