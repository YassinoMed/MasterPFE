<?php

namespace Tests\Feature;

use SecureRag\LaravelSecurity\Testing\ServiceAuthorizationTestAssertions;
use Tests\TestCase;

class AuthorizationSecurityTest extends TestCase
{
    use ServiceAuthorizationTestAssertions;

    protected function mutatingEndpoint(): string { return '/api/v1/conversations'; }
}
