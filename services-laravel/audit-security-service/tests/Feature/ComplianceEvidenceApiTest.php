<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ComplianceEvidenceApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_list_evidence(): void
    {
        $response = $this->getJson('/api/v1/compliance-evidence');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data',
                'meta' => ['current_page', 'per_page', 'total'],
            ]);
    }

    public function test_store_evidence(): void
    {
        $response = $this->postJson('/api/v1/compliance-evidence', [
            'control_id' => 'CTRL-001',
            'title' => 'Access Control Evidence',
            'summary' => 'IAM policies enforced',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.control_id', 'CTRL-001');
    }
}
