<?php

namespace Tests\Unit;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use App\Policies\UserPolicy;
use App\Policies\RolePolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PolicyTest extends TestCase
{
    use RefreshDatabase;

    private function userWithPermission(string $permission): User
    {
        $user = User::factory()->create();
        $role = Role::create(['name' => 'policy-role-' . rand(1000, 9999), 'label' => 'Policy', 'status' => 'active']);
        $perm = Permission::firstOrCreate(['name' => $permission], ['label' => $permission, 'domain' => 'test']);
        $role->permissions()->attach($perm);
        $user->roles()->attach($role);
        $user->load('roles.permissions');
        return $user;
    }

    // ── UserPolicy ──────────────────────────────────────────────────

    public function test_user_policy_view_any(): void
    {
        $policy = new UserPolicy();
        $actor = $this->userWithPermission('users.view');
        $this->assertTrue($policy->viewAny($actor));
    }

    public function test_user_policy_view_any_denied(): void
    {
        $policy = new UserPolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $this->assertFalse($policy->viewAny($actor));
    }

    public function test_user_policy_view_own(): void
    {
        $policy = new UserPolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $this->assertTrue($policy->view($actor, $actor));
    }

    public function test_user_policy_view_other_with_permission(): void
    {
        $policy = new UserPolicy();
        $actor = $this->userWithPermission('users.view');
        $target = User::factory()->create();
        $this->assertTrue($policy->view($actor, $target));
    }

    public function test_user_policy_view_other_denied(): void
    {
        $policy = new UserPolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $target = User::factory()->create();
        $this->assertFalse($policy->view($actor, $target));
    }

    public function test_user_policy_create(): void
    {
        $policy = new UserPolicy();
        $actor = $this->userWithPermission('users.create');
        $this->assertTrue($policy->create($actor));
    }

    public function test_user_policy_create_denied(): void
    {
        $policy = new UserPolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $this->assertFalse($policy->create($actor));
    }

    public function test_user_policy_update_own(): void
    {
        $policy = new UserPolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $this->assertTrue($policy->update($actor, $actor));
    }

    public function test_user_policy_update_other_with_permission(): void
    {
        $policy = new UserPolicy();
        $actor = $this->userWithPermission('users.update');
        $target = User::factory()->create();
        $this->assertTrue($policy->update($actor, $target));
    }

    public function test_user_policy_change_status(): void
    {
        $policy = new UserPolicy();
        $actor = $this->userWithPermission('users.disable');
        $this->assertTrue($policy->changeStatus($actor));
    }

    public function test_user_policy_change_status_denied(): void
    {
        $policy = new UserPolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $this->assertFalse($policy->changeStatus($actor));
    }

    // ── RolePolicy ──────────────────────────────────────────────────

    public function test_role_policy_view_any(): void
    {
        $policy = new RolePolicy();
        $actor = $this->userWithPermission('roles.view');
        $this->assertTrue($policy->viewAny($actor));
    }

    public function test_role_policy_view_any_denied(): void
    {
        $policy = new RolePolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $this->assertFalse($policy->viewAny($actor));
    }

    public function test_role_policy_view(): void
    {
        $policy = new RolePolicy();
        $actor = $this->userWithPermission('roles.view');
        $role = Role::create(['name' => 'view-target', 'label' => 'View', 'status' => 'active']);
        $this->assertTrue($policy->view($actor, $role));
    }

    public function test_role_policy_create(): void
    {
        $policy = new RolePolicy();
        $actor = $this->userWithPermission('roles.manage');
        $this->assertTrue($policy->create($actor));
    }

    public function test_role_policy_create_denied(): void
    {
        $policy = new RolePolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $this->assertFalse($policy->create($actor));
    }

    public function test_role_policy_update(): void
    {
        $policy = new RolePolicy();
        $actor = $this->userWithPermission('roles.manage');
        $role = Role::create(['name' => 'update-target', 'label' => 'Update', 'status' => 'active']);
        $this->assertTrue($policy->update($actor, $role));
    }

    public function test_role_policy_update_denied(): void
    {
        $policy = new RolePolicy();
        $actor = User::factory()->create();
        $actor->load('roles.permissions');
        $role = Role::create(['name' => 'deny-update', 'label' => 'Deny', 'status' => 'active']);
        $this->assertFalse($policy->update($actor, $role));
    }
}
