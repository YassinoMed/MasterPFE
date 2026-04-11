<?php

namespace Tests\Feature;

use Tests\TestCase;

class PortalPagesTest extends TestCase
{
    public function test_user_dashboard_is_available(): void
    {
        $this->get('/app')
            ->assertOk()
            ->assertSee('Portail utilisateur')
            ->assertSee('Legal Assistant');
    }

    public function test_admin_dashboard_is_available(): void
    {
        $this->get('/admin')
            ->assertOk()
            ->assertSee('Console administration')
            ->assertSee('Roles RBAC');
    }

    public function test_user_management_page_is_available(): void
    {
        $this->get('/admin/users')
            ->assertOk()
            ->assertSee('Gestion utilisateurs')
            ->assertSee('amina@example.local');
    }

    public function test_role_management_page_is_available(): void
    {
        $this->get('/admin/roles')
            ->assertOk()
            ->assertSee('Roles et permissions')
            ->assertSee('manage-chatbots');
    }

    public function test_chatbot_management_page_is_available(): void
    {
        $this->get('/chatbots')
            ->assertOk()
            ->assertSee('Gestion chatbots')
            ->assertSee('mock-adapter');
    }

    public function test_conversation_demo_is_available(): void
    {
        $this->get('/chat')
            ->assertOk()
            ->assertSee('Conversation demo')
            ->assertSee('Reponse demo');
    }

    public function test_conversation_history_page_is_available(): void
    {
        $this->get('/history')
            ->assertOk()
            ->assertSee('Historique conversations')
            ->assertSee('conv-2026-0411-001');
    }

    public function test_security_page_is_available(): void
    {
        $this->get('/security')
            ->assertOk()
            ->assertSee('Supervision securite')
            ->assertSee('SEC-2026-001');
    }

    public function test_devsecops_page_is_available(): void
    {
        $this->get('/devsecops')
            ->assertOk()
            ->assertSee('Supervision DevSecOps')
            ->assertSee('Jenkins');
    }

    public function test_portal_api_exposes_mocked_contracts(): void
    {
        $this->getJson('/api/v1/portal/devsecops-pipeline')
            ->assertOk()
            ->assertJsonPath('authority', 'Jenkins')
            ->assertJsonPath('officialScenario', 'demo');

        $this->getJson('/api/v1/portal/users')
            ->assertOk()
            ->assertJsonPath('users.0.role', 'user');

        $this->getJson('/api/v1/portal/conversation-history')
            ->assertOk()
            ->assertJsonPath('history.0.securityStatus', 'safe');
    }
}
