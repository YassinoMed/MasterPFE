<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreAuditLogRequest;
use App\Models\AuditLog;
use App\Services\SecurityAuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request, SecurityAuditService $service): JsonResponse
    {
        $page = $service->auditLogs($request->only(['actor_reference', 'resource_type', 'per_page']));

        return response()->json([
            'data' => collect($page->items())->map(fn (AuditLog $log): array => $this->serialize($log)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(StoreAuditLogRequest $request, SecurityAuditService $service): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($service->createAuditLog($request->validated())),
        ], 201);
    }

    private function serialize(AuditLog $log): array
    {
        return [
            'uuid' => $log->uuid,
            'actor_type' => $log->actor_type,
            'actor_reference' => $log->actor_reference,
            'action' => $log->action,
            'resource_type' => $log->resource_type,
            'resource_id' => $log->resource_id,
            'outcome' => $log->outcome,
            'ip_address' => $log->ip_address,
            'metadata' => $log->metadata ?? [],
            'occurred_at' => $log->occurred_at?->toISOString(),
        ];
    }
}
