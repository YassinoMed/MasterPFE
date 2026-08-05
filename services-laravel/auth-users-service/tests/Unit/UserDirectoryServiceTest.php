<?php

namespace Tests\Unit;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use App\Services\UserDirectoryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserDirectoryServiceTest extends TestCase
{
    use RefreshDatabase;

    private UserDirectoryService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = app(UserDirectoryService::class);
    }

    public function test_list_returns_paginated_results(): void
    {
        User::factory()->count(3)->create();
        $page = $this->service->list();
        $this->assertEquals(3, $page->total());
    }

    public function test_list_filters_by_status(): void
    {
        User::factory()->create(['status' => 'active']);
        User::factory()->create(['status' => 'locked']);

        $page = $this->service->list(['status' => 'active']);
        $this->assertEquals(1, $page->total());
    }

    public function test_list_filters_by_department(): void
    {
        User::factory()->create(['department' => 'IT']);
        User::factory()->create(['department' => 'HR']);

        $page = $this->service->list(['department' => 'IT']);
        $this->assertEquals(1, $page->total());
    }

    public function test_list_filters_by_search(): void
    {
        User::factory()->create(['first_name' => 'Alice', 'last_name' => 'Wonder', 'email' => 'alice@test.com']);
        User::factory()->create(['first_name' => 'Bob', 'last_name' => 'Builder', 'email' => 'bob@test.com']);

        $page = $this->service->list(['search' => 'Alice']);
        $this->assertEquals(1, $page->total());

        $page = $this->service->list(['search' => 'bob@test.com']);
        $this->assertEquals(1, $page->total());

        $page = $this->service->list(['search' => 'Builder']);
        $this->assertEquals(1, $page->total());
    }

    public function test_list_respects_per_page(): void
    {
        User::factory()->count(5)->create();

        $page = $this->service->list(['per_page' => 2]);
        $this->assertEquals(2, $page->perPage());
        $this->assertEquals(5, $page->total());
    }

    public function test_create_user_with_defaults(): void
    {
        $user = $this->service->create([
            'first_name' => 'New',
            'last_name' => 'User',
            'email' => 'new@test.com',
            'password' => 'SecurePass123!',
        ]);

        $this->assertEquals('pending_activation', $user->status);
        $this->assertEquals('new@test.com', $user->email);
    }

    public function test_create_user_with_roles(): void
    {
        $role = Role::create(['name' => 'test-role', 'label' => 'Test', 'status' => 'active']);

        $user = $this->service->create([
            'first_name' => 'Role',
            'last_name' => 'User',
            'email' => 'role@test.com',
            'password' => 'SecurePass123!',
            'roles' => ['test-role'],
        ]);

        $this->assertTrue($user->roles->contains('name', 'test-role'));
    }

    public function test_create_user_with_explicit_status(): void
    {
        $user = $this->service->create([
            'first_name' => 'Active',
            'last_name' => 'User',
            'email' => 'active@test.com',
            'password' => 'SecurePass123!',
            'status' => 'active',
        ]);

        $this->assertEquals('active', $user->status);
    }

    public function test_update_user_changes_fields(): void
    {
        $user = User::factory()->create(['first_name' => 'Old']);

        $updated = $this->service->update($user, ['first_name' => 'New']);
        $this->assertEquals('New', $updated->first_name);
    }

    public function test_update_user_with_password(): void
    {
        $user = User::factory()->create();
        $oldPassword = $user->password;

        $updated = $this->service->update($user, ['password' => 'NewSecure123!']);
        $this->assertNotEquals($oldPassword, $updated->password);
    }

    public function test_update_user_without_password(): void
    {
        $user = User::factory()->create();
        $oldPassword = $user->password;

        $updated = $this->service->update($user, ['first_name' => 'NoPassChange']);
        $this->assertEquals($oldPassword, $updated->password);
    }

    public function test_update_user_with_null_password(): void
    {
        $user = User::factory()->create();
        $oldPassword = $user->password;

        $updated = $this->service->update($user, ['password' => null, 'first_name' => 'Null']);
        $this->assertEquals($oldPassword, $updated->password);
    }

    public function test_update_status(): void
    {
        $user = User::factory()->create(['status' => 'active']);

        $updated = $this->service->updateStatus($user, 'locked');
        $this->assertEquals('locked', $updated->status);
    }

    public function test_sync_roles(): void
    {
        $user = User::factory()->create();
        $role1 = Role::create(['name' => 'role-a', 'label' => 'A', 'status' => 'active']);
        $role2 = Role::create(['name' => 'role-b', 'label' => 'B', 'status' => 'active']);

        $result = $this->service->syncRoles($user, ['role-a', 'role-b']);
        $this->assertCount(2, $result->roles);

        $result = $this->service->syncRoles($user, ['role-a']);
        $this->assertCount(1, $result->roles);
    }
}
