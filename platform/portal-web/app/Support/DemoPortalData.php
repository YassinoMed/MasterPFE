<?php

namespace App\Support;

final class DemoPortalData
{
    public static function userDashboard(): array
    {
        return [
            'profile' => [
                'name' => 'Amina Benali',
                'role' => 'Business Analyst',
                'workspace' => 'Direction Risques',
            ],
            'metrics' => [
                ['label' => 'Chatbots autorises', 'value' => 4, 'trend' => '+1 ce mois'],
                ['label' => 'Conversations', 'value' => 128, 'trend' => '+18%'],
                ['label' => 'Reponses bloquees', 'value' => 3, 'trend' => 'controle actif'],
                ['label' => 'Documents consultes', 'value' => 42, 'trend' => 'demo'],
            ],
            'chatbots' => self::chatbots(),
            'recentConversations' => [
                ['title' => 'Analyse clause fournisseur', 'chatbot' => 'Legal Assistant', 'status' => 'safe', 'updatedAt' => '2026-04-11 09:30'],
                ['title' => 'Synthese tickets support', 'chatbot' => 'Support Copilot', 'status' => 'safe', 'updatedAt' => '2026-04-11 08:45'],
                ['title' => 'Question donnees sensibles', 'chatbot' => 'HR Policy Bot', 'status' => 'filtered', 'updatedAt' => '2026-04-10 17:20'],
            ],
        ];
    }

    public static function adminDashboard(): array
    {
        return [
            'metrics' => [
                ['label' => 'Utilisateurs actifs', 'value' => 37, 'status' => 'ok'],
                ['label' => 'Roles RBAC', 'value' => 5, 'status' => 'ok'],
                ['label' => 'Chatbots publies', 'value' => 6, 'status' => 'ok'],
                ['label' => 'Incidents ouverts', 'value' => 2, 'status' => 'watch'],
            ],
            'users' => self::users(),
            'roles' => self::roles(),
        ];
    }

    public static function users(): array
    {
        return [
            [
                'name' => 'Amina Benali',
                'email' => 'amina@example.local',
                'role' => 'user',
                'team' => 'Direction Risques',
                'status' => 'active',
                'lastLogin' => '2026-04-11 09:30',
            ],
            [
                'name' => 'Yassine Med',
                'email' => 'yassine@example.local',
                'role' => 'admin',
                'team' => 'Plateforme',
                'status' => 'active',
                'lastLogin' => '2026-04-11 08:55',
            ],
            [
                'name' => 'Nora Audit',
                'email' => 'nora@example.local',
                'role' => 'security_analyst',
                'team' => 'Cyber Defense',
                'status' => 'active',
                'lastLogin' => '2026-04-10 18:12',
            ],
            [
                'name' => 'Karim Support',
                'email' => 'karim@example.local',
                'role' => 'chatbot_manager',
                'team' => 'Support Client',
                'status' => 'pending',
                'lastLogin' => 'jamais',
            ],
        ];
    }

    public static function roles(): array
    {
        return [
            [
                'name' => 'admin',
                'description' => 'Administration globale du portail demo.',
                'users' => 2,
                'permissions' => ['manage-users', 'manage-roles', 'manage-chatbots', 'view-audit', 'view-devsecops'],
            ],
            [
                'name' => 'security_analyst',
                'description' => 'Suivi des incidents, guardrails et preuves de securite.',
                'users' => 3,
                'permissions' => ['view-audit', 'review-incidents', 'export-evidence'],
            ],
            [
                'name' => 'chatbot_manager',
                'description' => 'Configuration fonctionnelle des chatbots metiers.',
                'users' => 4,
                'permissions' => ['manage-chatbots', 'view-chatbot-metrics'],
            ],
            [
                'name' => 'user',
                'description' => 'Utilisation controlee des chatbots publies.',
                'users' => 28,
                'permissions' => ['use-chatbots', 'view-history'],
            ],
        ];
    }

    public static function chatbots(): array
    {
        return [
            [
                'name' => 'Legal Assistant',
                'domain' => 'Juridique',
                'sensitivity' => 'confidentiel',
                'status' => 'published',
                'guardrail' => 'Filtrage PII + refus hors perimetre',
                'owner' => 'Direction Juridique',
                'modelMode' => 'mock-adapter',
                'temperature' => '0.20',
            ],
            [
                'name' => 'Support Copilot',
                'domain' => 'Support client',
                'sensitivity' => 'interne',
                'status' => 'published',
                'guardrail' => 'Citations sources obligatoires',
                'owner' => 'Support Client',
                'modelMode' => 'mock-adapter',
                'temperature' => '0.30',
            ],
            [
                'name' => 'HR Policy Bot',
                'domain' => 'Ressources humaines',
                'sensitivity' => 'sensible',
                'status' => 'restricted',
                'guardrail' => 'Masquage donnees personnelles',
                'owner' => 'Ressources Humaines',
                'modelMode' => 'mock-adapter',
                'temperature' => '0.10',
            ],
        ];
    }

    public static function conversationHistory(): array
    {
        return [
            [
                'id' => 'conv-2026-0411-001',
                'title' => 'Analyse clause fournisseur',
                'chatbot' => 'Legal Assistant',
                'user' => 'Amina Benali',
                'messages' => 8,
                'securityStatus' => 'safe',
                'updatedAt' => '2026-04-11 09:30',
            ],
            [
                'id' => 'conv-2026-0411-002',
                'title' => 'Synthese tickets support',
                'chatbot' => 'Support Copilot',
                'user' => 'Karim Support',
                'messages' => 12,
                'securityStatus' => 'safe',
                'updatedAt' => '2026-04-11 08:45',
            ],
            [
                'id' => 'conv-2026-0410-004',
                'title' => 'Question donnees sensibles',
                'chatbot' => 'HR Policy Bot',
                'user' => 'Nora Audit',
                'messages' => 5,
                'securityStatus' => 'filtered',
                'updatedAt' => '2026-04-10 17:20',
            ],
        ];
    }

    public static function conversation(): array
    {
        return [
            'conversation' => [
                'id' => 'demo-conv-001',
                'title' => 'Analyse clause fournisseur',
                'chatbot' => 'Legal Assistant',
                'securityStatus' => 'safe',
            ],
            'messages' => [
                ['sender' => 'user', 'body' => 'Resume les risques de cette clause de confidentialite.', 'time' => '09:28'],
                ['sender' => 'assistant', 'body' => 'Reponse demo: la clause presente un risque moyen sur la duree, le perimetre et les exceptions.', 'time' => '09:29'],
                ['sender' => 'security', 'body' => 'Controle: aucune donnee personnelle detectee. Sources requises en mode reel.', 'time' => '09:29'],
            ],
            'sources' => [
                ['title' => 'Contrat fournisseur - extrait demo', 'confidence' => '0.86'],
                ['title' => 'Politique juridique interne - demo', 'confidence' => '0.78'],
            ],
        ];
    }

    public static function securityIncidents(): array
    {
        return [
            'summary' => [
                ['label' => 'Incidents ouverts', 'value' => 2],
                ['label' => 'Reponses filtrees', 'value' => 9],
                ['label' => 'Tentatives prompt injection', 'value' => 4],
            ],
            'incidents' => [
                ['id' => 'SEC-2026-001', 'severity' => 'medium', 'type' => 'prompt-injection', 'status' => 'triage', 'service' => 'llm-orchestrator'],
                ['id' => 'SEC-2026-002', 'severity' => 'low', 'type' => 'pii-detected', 'status' => 'contained', 'service' => 'security-auditor'],
                ['id' => 'SEC-2026-003', 'severity' => 'info', 'type' => 'policy-audit', 'status' => 'closed', 'service' => 'kyverno'],
            ],
        ];
    }

    public static function devsecopsPipeline(): array
    {
        return [
            'authority' => 'Jenkins',
            'officialScenario' => 'demo',
            'githubActions' => 'legacy',
            'stages' => [
                ['name' => 'CI', 'status' => 'green', 'evidence' => 'tests, coverage, Ruff, Semgrep, Gitleaks, Trivy'],
                ['name' => 'Build', 'status' => 'ready', 'evidence' => 'local registry images'],
                ['name' => 'SBOM', 'status' => 'partial', 'evidence' => 'Syft script ready'],
                ['name' => 'Sign', 'status' => 'partial', 'evidence' => 'Cosign keys required'],
                ['name' => 'Promote digest', 'status' => 'partial', 'evidence' => 'digest-first script ready'],
                ['name' => 'Deploy demo', 'status' => 'green', 'evidence' => 'kind namespace and pods running'],
                ['name' => 'Validate', 'status' => 'green', 'evidence' => 'health endpoints and support pack'],
            ],
        ];
    }
}
