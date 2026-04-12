<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSecurityIncidentRequest;
use App\Http\Requests\UpdateIncidentStatusRequest;
use App\Models\SecurityIncident;
use App\Services\SecurityAuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SecurityIncidentController extends Controller
{
    public function index(Request $request, SecurityAuditService $service): JsonResponse
    {
        $page = $service->incidents($request->only(['severity', 'status', 'source', 'per_page']));

        return response()->json([
            'data' => collect($page->items())->map(fn (SecurityIncident $incident): array => $this->serialize($incident)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(StoreSecurityIncidentRequest $request, SecurityAuditService $service): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($service->createIncident($request->validated())),
        ], 201);
    }

    public function show(SecurityIncident $incident): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($incident),
        ]);
    }

    public function status(UpdateIncidentStatusRequest $request, SecurityIncident $incident, SecurityAuditService $service): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($service->updateIncidentStatus($incident, $request->validated())),
        ]);
    }

    private function serialize(SecurityIncident $incident): array
    {
        return [
            'uuid' => $incident->uuid,
            'title' => $incident->title,
            'severity' => $incident->severity,
            'status' => $incident->status,
            'source' => $incident->source,
            'description' => $incident->description,
            'detected_at' => $incident->detected_at?->toISOString(),
            'resolved_at' => $incident->resolved_at?->toISOString(),
            'metadata' => $incident->metadata ?? [],
        ];
    }
}
