<?php

namespace Tests\Unit;

use App\Models\Permission;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PermissionModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_permission_generates_uuid_on_creation(): void
    {
        $permission = Permission::create(['name' => 'auto.perm', 'label' => 'Auto', 'domain' => 'test']);
        $this->assertNotNull($permission->uuid);
        $this->assertTrue(strlen($permission->uuid) === 36);
    }

    public function test_permission_keeps_provided_uuid(): void
    {
        $uuid = 'custom-perm-uuid-5678';
        $permission = Permission::create(['uuid' => $uuid, 'name' => 'kept.perm', 'label' => 'Kept', 'domain' => 'test']);
        $this->assertEquals($uuid, $permission->uuid);
    }

    public function test_route_key_name_is_uuid(): void
    {
        $permission = new Permission();
        $this->assertEquals('uuid', $permission->getRouteKeyName());
    }

    public function test_fillable_attributes(): void
    {
        $permission = new Permission();
        $this->assertContains('name', $permission->getFillable());
        $this->assertContains('label', $permission->getFillable());
        $this->assertContains('domain', $permission->getFillable());
        $this->assertContains('description', $permission->getFillable());
    }

    public function test_roles_relationship(): void
    {
        $permission = Permission::create(['name' => 'rel.perm', 'label' => 'Rel', 'domain' => 'test']);
        $role = Role::create(['name' => 'rel-role', 'label' => 'Rel', 'status' => 'active']);
        $permission->roles()->attach($role);
        $permission->load('roles');

        $this->assertCount(1, $permission->roles);
    }
}
