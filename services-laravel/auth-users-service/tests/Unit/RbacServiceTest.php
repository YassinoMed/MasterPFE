<?php

namespace Tests\Unit;

use App\Models\Role;
use App\Services\RbacService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RbacServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_syncs_baseline_roles_and_permissions(): void
    {
        app(RbacService::class)->syncBaseline();

        $this->assertDatabaseHas('roles', ['name' => 'super-admin']);
        $this->assertDatabaseHas('roles', ['name' => 'admin-plateforme']);
        $this->assertDatabaseHas('permissions', ['name' => 'users.view']);
        $this->assertDatabaseHas('permissions', ['name' => 'conversations.use.it']);

        $superAdmin = Role::query()
            ->where('name', 'super-admin')
            ->with('permissions')
            ->firstOrFail();

        $this->assertTrue($superAdmin->permissions->contains('name', 'roles.manage'));
        $this->assertTrue($superAdmin->permissions->contains('name', 'chatbots.manage'));
    }
}
