<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreRoleRequest;
use App\Http\Requests\UpdateRoleRequest;
use App\Models\Role;
use App\Services\RbacService;
use Illuminate\Http\JsonResponse;

class RoleController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'data' => Role::query()
                ->with('permissions')
                ->withCount('users')
                ->orderBy('name')
                ->get()
                ->map(fn (Role $role): array => $this->serializeRole($role)),
        ]);
    }

    public function store(StoreRoleRequest $request, RbacService $rbac): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeRole($rbac->createRole($request->validated())),
        ], 201);
    }

    public function show(Role $role): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeRole($role->load('permissions')->loadCount('users')),
        ]);
    }

    public function update(UpdateRoleRequest $request, Role $role, RbacService $rbac): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeRole($rbac->updateRole($role, $request->validated())->loadCount('users')),
        ]);
    }

    private function serializeRole(Role $role): array
    {
        return [
            'uuid' => $role->uuid,
            'name' => $role->name,
            'label' => $role->label,
            'description' => $role->description,
            'status' => $role->status,
            'users_count' => $role->users_count ?? null,
            'permissions' => $role->permissions->map(fn ($permission): array => [
                'uuid' => $permission->uuid,
                'name' => $permission->name,
                'label' => $permission->label,
                'domain' => $permission->domain,
            ])->values(),
        ];
    }
}
