<?php

namespace Tests\Feature;

use Tests\TestCase;

class HealthControllerTest extends TestCase
{
    public function test_health_endpoint_returns_ok(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response->assertStatus(200)
            ->assertJson([
                'service' => 'auth-users-service',
                'status' => 'ok',
                'version' => 'v1',
            ]);
    }

    public function test_health_endpoint_has_json_content_type(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response->assertHeader('Content-Type', 'application/json');
    }

    public function test_health_endpoint_structure(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response->assertJsonStructure([
            'service',
            'status',
            'version',
        ]);
    }
}
