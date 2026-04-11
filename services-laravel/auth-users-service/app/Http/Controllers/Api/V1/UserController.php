<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\AttachUserRolesRequest;
use App\Http\Requests\StoreUserRequest;
use App\Http\Requests\UpdateUserRequest;
use App\Http\Requests\UpdateUserStatusRequest;
use App\Models\User;
use App\Services\UserDirectoryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index(Request $request, UserDirectoryService $users): JsonResponse
    {
        $page = $users->list($request->only(['search', 'status', 'department', 'per_page']));

        return response()->json([
            'data' => collect($page->items())->map(fn (User $user): array => $this->serializeUser($user)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(StoreUserRequest $request, UserDirectoryService $users): JsonResponse
    {
        $user = $users->create($request->validated());

        return response()->json([
            'data' => $this->serializeUser($user),
        ], 201);
    }

    public function show(User $user): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeUser($user->load('roles.permissions')),
        ]);
    }

    public function update(UpdateUserRequest $request, User $user, UserDirectoryService $users): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeUser($users->update($user, $request->validated())),
        ]);
    }

    public function status(UpdateUserStatusRequest $request, User $user, UserDirectoryService $users): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeUser($users->updateStatus($user, $request->validated('status'))),
        ]);
    }

    public function roles(AttachUserRolesRequest $request, User $user, UserDirectoryService $users): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeUser($users->syncRoles($user, $request->validated('roles'))),
        ]);
    }

    private function serializeUser(User $user): array
    {
        return [
            'uuid' => $user->uuid,
            'first_name' => $user->first_name,
            'last_name' => $user->last_name,
            'email' => $user->email,
            'status' => $user->status,
            'department' => $user->department,
            'job_title' => $user->job_title,
            'roles' => $user->roles->map(fn ($role): array => [
                'uuid' => $role->uuid,
                'name' => $role->name,
                'label' => $role->label,
                'permissions' => $role->permissions->pluck('name')->values(),
            ])->values(),
            'permissions' => $user->roles
                ->flatMap(fn ($role) => $role->permissions->pluck('name'))
                ->unique()
                ->values(),
            'created_at' => $user->created_at?->toISOString(),
            'updated_at' => $user->updated_at?->toISOString(),
        ];
    }
}
