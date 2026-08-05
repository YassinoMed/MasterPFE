<?php

namespace Tests\Unit;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RoleModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_role_generates_uuid_on_creation(): void
    {
        $role = Role::create(['name' => 'auto-uuid', 'label' => 'Auto', 'status' => 'active']);
        $this->assertNotNull($role->uuid);
        $this->assertTrue(strlen($role->uuid) === 36);
    }

    public function test_role_keeps_provided_uuid(): void
    {
        $uuid = 'custom-role-uuid-1234';
        $role = Role::create(['uuid' => $uuid, 'name' => 'kept-uuid', 'label' => 'Kept', 'status' => 'active']);
        $this->assertEquals($uuid, $role->uuid);
    }

    public function test_route_key_name_is_uuid(): void
    {
        $role = new Role();
        $this->assertEquals('uuid', $role->getRouteKeyName());
    }

    public function test_role_fillable_attributes(): void
    {
        $role = new Role();
        $this->assertContains('name', $role->getFillable());
        $this->assertContains('label', $role->getFillable());
        $this->assertContains('description', $role->getFillable());
        $this->assertContains('status', $role->getFillable());
    }

    public function test_permissions_relationship(): void
    {
        $role = Role::create(['name' => 'perm-rel', 'label' => 'Perm', 'status' => 'active']);
        $this->assertCount(0, $role->permissions);

        $permission = Permission::create(['name' => 'test.perm', 'label' => 'Test', 'domain' => 'test']);
        $role->permissions()->attach($permission);
        $role->load('permissions');

        $this->assertCount(1, $role->permissions);
    }

    public function test_users_relationship(): void
    {
        $role = Role::create(['name' => 'usr-rel', 'label' => 'User Rel', 'status' => 'active']);
        $user = User::factory()->create();
        $role->users()->attach($user);
        $role->load('users');

        $this->assertCount(1, $role->users);
    }
}
