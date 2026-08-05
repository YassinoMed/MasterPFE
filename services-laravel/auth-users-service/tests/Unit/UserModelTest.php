<?php

namespace Tests\Unit;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_generates_uuid_on_creation(): void
    {
        $user = User::factory()->create(['uuid' => null]);
        $this->assertNotNull($user->uuid);
        $this->assertTrue(strlen($user->uuid) === 36);
    }

    public function test_user_keeps_provided_uuid(): void
    {
        $uuid = 'custom-uuid-1234-5678-9012';
        $user = User::factory()->create(['uuid' => $uuid]);
        $this->assertEquals($uuid, $user->uuid);
    }

    public function test_route_key_name_is_uuid(): void
    {
        $user = new User();
        $this->assertEquals('uuid', $user->getRouteKeyName());
    }

    public function test_password_is_hidden(): void
    {
        $user = User::factory()->create();
        $array = $user->toArray();
        $this->assertArrayNotHasKey('password', $array);
        $this->assertArrayNotHasKey('remember_token', $array);
    }

    public function test_has_role_returns_true_when_role_assigned(): void
    {
        $user = User::factory()->create();
        $role = Role::create(['name' => 'test-role', 'label' => 'Test', 'status' => 'active']);
        $user->roles()->attach($role);
        $user->load('roles');

        $this->assertTrue($user->hasRole('test-role'));
        $this->assertFalse($user->hasRole('nonexistent'));
    }

    public function test_has_permission_through_role(): void
    {
        $user = User::factory()->create();
        $role = Role::create(['name' => 'perm-role', 'label' => 'Perm', 'status' => 'active']);
        $permission = Permission::create(['name' => 'test.action', 'label' => 'Test Action', 'domain' => 'test']);
        $role->permissions()->attach($permission);
        $user->roles()->attach($role);
        $user->load('roles.permissions');

        $this->assertTrue($user->hasPermission('test.action'));
        $this->assertFalse($user->hasPermission('nonexistent.action'));
    }

    public function test_user_fillable_attributes(): void
    {
        $user = new User();
        $this->assertContains('first_name', $user->getFillable());
        $this->assertContains('email', $user->getFillable());
        $this->assertContains('status', $user->getFillable());
        $this->assertContains('department', $user->getFillable());
        $this->assertContains('job_title', $user->getFillable());
    }

    public function test_user_casts_dates(): void
    {
        $user = User::factory()->create(['last_login_at' => now()]);
        $this->assertNotNull($user->last_login_at);
    }

    public function test_roles_relationship(): void
    {
        $user = User::factory()->create();
        $this->assertCount(0, $user->roles);

        $role = Role::create(['name' => 'rel-test', 'label' => 'Rel', 'status' => 'active']);
        $user->roles()->attach($role);
        $user->load('roles');

        $this->assertCount(1, $user->roles);
    }
}
