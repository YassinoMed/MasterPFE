<?php

namespace Tests\Unit;

use App\Policies\BusinessDomainPolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BusinessDomainPolicyTest extends TestCase
{
    use RefreshDatabase;

    private BusinessDomainPolicy $policy;

    protected function setUp(): void
    {
        parent::setUp();
        $this->policy = new BusinessDomainPolicy();
    }

    public function test_policy_exists(): void
    {
        $this->assertInstanceOf(BusinessDomainPolicy::class, $this->policy);
    }

    public function test_view_any_is_callable(): void
    {
        $result = $this->policy->viewAny(null);
        $this->assertIsBool($result);
    }

    public function test_create_is_callable(): void
    {
        $result = $this->policy->create(null);
        $this->assertIsBool($result);
    }
}
