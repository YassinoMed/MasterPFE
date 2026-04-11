<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreBusinessDomainRequest;
use App\Http\Requests\UpdateBusinessDomainRequest;
use App\Models\BusinessDomain;
use App\Services\ChatbotCatalogService;
use Illuminate\Http\JsonResponse;

class BusinessDomainController extends Controller
{
    public function index(ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $catalog->domains()->get()->map(fn (BusinessDomain $domain): array => $this->serializeDomain($domain)),
        ]);
    }

    public function store(StoreBusinessDomainRequest $request, ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeDomain($catalog->createDomain($request->validated())),
        ], 201);
    }

    public function show(BusinessDomain $domain): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeDomain($domain),
        ]);
    }

    public function update(UpdateBusinessDomainRequest $request, BusinessDomain $domain, ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeDomain($catalog->updateDomain($domain, $request->validated())),
        ]);
    }

    private function serializeDomain(BusinessDomain $domain): array
    {
        return [
            'uuid' => $domain->uuid,
            'name' => $domain->name,
            'slug' => $domain->slug,
            'description' => $domain->description,
            'status' => $domain->status,
        ];
    }
}
