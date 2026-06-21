<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreChatbotRequest;
use App\Http\Requests\UpdateChatbotRequest;
use App\Http\Requests\UpdateChatbotRolesRequest;
use App\Http\Requests\UpdateChatbotStatusRequest;
use App\Models\Chatbot;
use App\Services\ChatbotCatalogService;
use App\Services\ChatbotGovernanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatbotController extends Controller
{
    public function index(Request $request, ChatbotCatalogService $catalog): JsonResponse
    {
        $page = $catalog->chatbots($request->only(['search', 'status', 'domain', 'per_page']));

        return response()->json([
            'data' => collect($page->items())->map(fn (Chatbot $chatbot): array => $this->serializeChatbot($chatbot)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(StoreChatbotRequest $request, ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeChatbot($catalog->createChatbot($request->validated())),
        ], 201);
    }

    public function show(Chatbot $chatbot): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeChatbot($chatbot->load(['businessDomain', 'sensitivityLevel', 'promptConfigs', 'accessRules'])),
        ]);
    }

    public function update(UpdateChatbotRequest $request, Chatbot $chatbot, ChatbotCatalogService $catalog): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeChatbot($catalog->updateChatbot($chatbot, $request->validated())),
        ]);
    }

    public function status(UpdateChatbotStatusRequest $request, Chatbot $chatbot, ChatbotGovernanceService $governance): JsonResponse
    {
        return response()->json([
            'data' => $this->serializeChatbot($governance->updateStatus(
                $chatbot,
                $request->validated('status'),
                $request->validated('is_active'),
            )),
        ]);
    }

    public function roles(Chatbot $chatbot, ChatbotGovernanceService $governance): JsonResponse
    {
        return response()->json([
            'data' => $governance->roles($chatbot),
        ]);
    }

    public function updateRoles(UpdateChatbotRolesRequest $request, Chatbot $chatbot, ChatbotGovernanceService $governance): JsonResponse
    {
        return response()->json([
            'data' => $governance->syncRoles($chatbot, $request->validated('roles')),
        ]);
    }

    private function serializeChatbot(Chatbot $chatbot): array
    {
        return [
            'uuid' => $chatbot->uuid,
            'name' => $chatbot->name,
            'slug' => $chatbot->slug,
            'description' => $chatbot->description,
            'business_domain' => [
                'uuid' => $chatbot->businessDomain?->uuid,
                'name' => $chatbot->businessDomain?->name,
                'slug' => $chatbot->businessDomain?->slug,
            ],
            'sensitivity_level' => [
                'uuid' => $chatbot->sensitivityLevel?->uuid,
                'name' => $chatbot->sensitivityLevel?->name,
                'slug' => $chatbot->sensitivityLevel?->slug,
                'rank' => $chatbot->sensitivityLevel?->rank,
            ],
            'status' => $chatbot->status,
            'visibility' => $chatbot->visibility,
            'system_prompt_version' => $chatbot->system_prompt_version,
            'security_profile' => $chatbot->security_profile,
            'is_active' => $chatbot->is_active,
            'settings' => $chatbot->settings ?? [],
            'access_rules' => $chatbot->accessRules->map(fn ($rule): array => [
                'uuid' => $rule->uuid,
                'rule_type' => $rule->rule_type,
                'rule_payload' => $rule->rule_payload,
                'is_enabled' => $rule->is_enabled,
            ])->values(),
        ];
    }
}
