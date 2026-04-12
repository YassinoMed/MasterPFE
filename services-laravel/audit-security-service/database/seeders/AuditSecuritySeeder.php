<?php

namespace Database\Seeders;

use App\Services\SecurityAuditService;
use Illuminate\Database\Seeder;

class AuditSecuritySeeder extends Seeder
{
    public function run(): void
    {
        $service = app(SecurityAuditService::class);

        $service->createIncident([
            'title' => 'Tentative acces chatbot RH par role non autorise',
            'severity' => 'medium',
            'status' => 'triaged',
            'source' => 'portal-demo',
            'description' => 'Incident synthetique pour demontrer la supervision RBAC.',
            'metadata' => ['scenario' => 'demo'],
        ]);

        $service->createAuditLog([
            'actor_reference' => 'admin@example.test',
            'action' => 'chatbot.roles.updated',
            'resource_type' => 'chatbot',
            'resource_id' => 'chatbot-rh',
            'outcome' => 'success',
            'metadata' => ['roles' => ['user-rh', 'admin-plateforme']],
        ]);

        $service->createEvidence([
            'control_id' => 'DEVSECOPS-CI-001',
            'title' => 'Pipeline CI qualite securite',
            'status' => 'pass',
            'evidence_uri' => 'artifacts/final/final-validation-summary.md',
            'summary' => 'Preuve demo synthetique du pipeline qualite et securite.',
            'metadata' => ['jenkins' => 'official'],
        ]);
    }
}
