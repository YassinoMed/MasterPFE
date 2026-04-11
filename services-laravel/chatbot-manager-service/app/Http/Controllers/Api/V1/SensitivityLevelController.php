<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSensitivityLevelRequest;
use App\Http\Requests\UpdateSensitivityLevelRequest;
use App\Models\SensitivityLevel;
use App\Services\ChatbotCatalogService;
use Illuminate\Http\JsonResponse;

class SensitivityLevelController extends Controller
{
    public function index(ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $catalog->sensitivityLevels()->get()->map(fn (SensitivityLevel $level): array => $this->serializeLevel($level)),
        ]);
    }

    public function store(StoreSensitivityLevelRequest $request, ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeLevel($catalog->createSensitivityLevel($request->validated())),
        ], 201);
    }

    public function show(SensitivityLevel $level): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeLevel($level),
        ]);
    }

    public function update(UpdateSensitivityLevelRequest $request, SensitivityLevel $level, ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeLevel($catalog->updateSensitivityLevel($level, $request->validated())),
        ]);
    }

    private function serializeLevel(SensitivityLevel $level): array
    {
        return [
            'uuid' => $level->uuid,
            'name' => $level->name,
            'slug' => $level->slug,
            'rank' => $level->rank,
            'description' => $level->description,
        ];
    }
}
