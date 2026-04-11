<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StorePromptConfigRequest;
use App\Models\Chatbot;
use App\Models\ChatbotPromptConfig;
use App\Services\ChatbotGovernanceService;
use Illuminate\Http\JsonResponse;

class ChatbotPromptConfigController extends Controller
{
    public function index(Chatbot $chatbot): JsonResponse
    {
        return response()->json([
            'data' => $chatbot->promptConfigs()
                ->orderByDesc('is_current')
                ->orderByDesc('created_at')
                ->get()
                ->map(fn (ChatbotPromptConfig $config): array => $this->serializeConfig($config)),
        ]);
    }

    public function store(StorePromptConfigRequest $request, Chatbot $chatbot, ChatbotGovernanceService $governance): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeConfig($governance->addPromptConfig($chatbot, $request->validated())),
        ], 201);
    }

    private function serializeConfig(ChatbotPromptConfig $config): array
    {
        return [
            'uuid' => $config->uuid,
            'version' => $config->version,
            'system_prompt' => $config->system_prompt,
            'is_current' => $config->is_current,
            'change_note' => $config->change_note,
            'created_at' => $config->created_at?->toISOString(),
        ];
    }
}
