<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StoreSecurityIncidentRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_incident_validates_title_required(): void
    {
        $response = $this->postJson('/api/v1/incidents', [
            'severity' => 'high',
            'source' => 'test-suite',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['title']);
    }

    public function test_store_incident_validates_severity_required(): void
    {
        $response = $this->postJson('/api/v1/incidents', [
            'title' => 'Test Incident',
            'source' => 'test-suite',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['severity']);
    }

    public function test_store_incident_validates_severity_values(): void
    {
        $response = $this->postJson('/api/v1/incidents', [
            'title' => 'Test Incident',
            'severity' => 'invalid',
            'source' => 'test-suite',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['severity']);
    }

    public function test_store_incident_accepts_valid_severities(): void
    {
        foreach (['low', 'medium', 'high', 'critical'] as $severity) {
            $response = $this->postJson('/api/v1/incidents', [
                'title' => "Test {$severity}",
                'severity' => $severity,
                'source' => 'test-suite',
            ]);

            $response->assertStatus(201);
        }
    }

    public function test_store_incident_validates_source_required(): void
    {
        $response = $this->postJson('/api/v1/incidents', [
            'title' => 'Test Incident',
            'severity' => 'medium',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['source']);
    }

    public function test_store_incident_validates_title_max_length(): void
    {
        $response = $this->postJson('/api/v1/incidents', [
            'title' => str_repeat('a', 181),
            'severity' => 'medium',
            'source' => 'test-suite',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['title']);
    }
}
