<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreComplianceEvidenceRequest;
use App\Models\ComplianceEvidence;
use App\Services\SecurityAuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ComplianceEvidenceController extends Controller
{
    public function index(Request $request, SecurityAuditService $service): JsonResponse
    {
        $page = $service->evidence($request->only(['control_id', 'status', 'per_page']));

        return response()->json([
            'data' => collect($page->items())->map(fn (ComplianceEvidence $evidence): array => $this->serialize($evidence)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(StoreComplianceEvidenceRequest $request, SecurityAuditService $service): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($service->createEvidence($request->validated())),
        ], 201);
    }

    private function serialize(ComplianceEvidence $evidence): array
    {
        return [
            'uuid' => $evidence->uuid,
            'control_id' => $evidence->control_id,
            'title' => $evidence->title,
            'status' => $evidence->status,
            'evidence_uri' => $evidence->evidence_uri,
            'summary' => $evidence->summary,
            'collected_at' => $evidence->collected_at?->toISOString(),
            'metadata' => $evidence->metadata ?? [],
        ];
    }
}
