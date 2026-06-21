<?php

namespace Tests\Feature;

use Tests\TestCase;

class AllPortalRoutesTest extends TestCase
{
    public function test_welcome_route(): void
    {
        $response = $this->get('/');
        $this->assertTrue(in_array($response->status(), [200, 302]));
    }

    public function test_health_endpoint_returns_ok(): void
    {
        $response = $this->get('/health');
        $this->assertEquals(200, $response->status());
    }

    public function test_devsecops_page(): void
    {
        $response = $this->get('/devsecops');
        $this->assertTrue(in_array($response->status(), [200, 302]));
    }

    public function test_chat_page(): void
    {
        $response = $this->get('/chat');
        $this->assertTrue(in_array($response->status(), [200, 302]));
    }
}
