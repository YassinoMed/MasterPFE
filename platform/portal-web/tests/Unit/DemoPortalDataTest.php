<?php

namespace Tests\Unit;

use App\Support\DemoPortalData;
use Tests\TestCase;

class DemoPortalDataTest extends TestCase
{
    public function test_users_returns_array(): void
    {
        $users = DemoPortalData::users();
        $this->assertIsArray($users);
        $this->assertNotEmpty($users);
    }

    public function test_roles_returns_array(): void
    {
        $roles = DemoPortalData::roles();
        $this->assertIsArray($roles);
        $this->assertNotEmpty($roles);
    }

    public function test_chatbots_returns_array(): void
    {
        $chatbots = DemoPortalData::chatbots();
        $this->assertIsArray($chatbots);
        $this->assertNotEmpty($chatbots);
    }

    public function test_conversation_returns_valid_structure(): void
    {
        $data = DemoPortalData::conversation();
        $this->assertArrayHasKey('messages', $data);
        $this->assertArrayHasKey('sources', $data);
    }

    public function test_conversation_history_returns_array(): void
    {
        $history = DemoPortalData::conversationHistory();
        $this->assertIsArray($history);
    }

    public function test_security_incidents_returns_array(): void
    {
        $incidents = DemoPortalData::securityIncidents();
        $this->assertArrayHasKey('summary', $incidents);
        $this->assertArrayHasKey('incidents', $incidents);
    }

    public function test_user_dashboard_returns_valid_structure(): void
    {
        $dashboard = DemoPortalData::userDashboard();
        $this->assertArrayHasKey('profile', $dashboard);
        $this->assertArrayHasKey('metrics', $dashboard);
        $this->assertArrayHasKey('chatbots', $dashboard);
        $this->assertArrayHasKey('recentConversations', $dashboard);
    }

    public function test_admin_dashboard_returns_array(): void
    {
        $dashboard = DemoPortalData::adminDashboard();
        $this->assertIsArray($dashboard);
    }

    public function test_mock_chatbot_returns_valid_structure(): void
    {
        $chatbot = DemoPortalData::chatbots();
        $this->assertIsArray($chatbot);
        $this->assertNotEmpty($chatbot);
        $this->assertArrayHasKey('name', $chatbot[0]);
    }
}
