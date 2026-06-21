<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\RbacService;
use Illuminate\Http\JsonResponse;

class PermissionController extends Controller
{
    public function __invoke(RbacService $rbac): JsonResponse
    {
        return response()->json([
            'data' => $rbac->permissions()->map(fn ($permission): array => [
                'uuid' => $permission->uuid,
                'name' => $permission->name,
                'label' => $permission->label,
                'domain' => $permission->domain,
                'description' => $permission->description,
            ]),
        ]);
    }
}
