<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreConversationRequest;
use App\Http\Requests\UpdateConversationStatusRequest;
use App\Models\Conversation;
use App\Services\ConversationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConversationController extends Controller
{
    public function index(Request $request, ConversationService $service): JsonResponse
    {
        $page = $service->list($request->only(['user_reference', 'chatbot_slug', 'status', 'per_page']));

        return response()->json([
            'data' => collect($page->items())->map(fn (Conversation $conversation): array => $this->serialize($conversation)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(StoreConversationRequest $request, ConversationService $service): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($service->create($request->validated())),
        ], 201);
    }

    public function show(Conversation $conversation): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($conversation->load('messages')),
        ]);
    }

    public function status(UpdateConversationStatusRequest $request, Conversation $conversation, ConversationService $service): JsonResponse
    {
        return response()->json([
            'data' => $this->serialize($service->updateStatus($conversation, $request->validated('status'))),
        ]);
    }

    private function serialize(Conversation $conversation): array
    {
        return [
            'uuid' => $conversation->uuid,
            'chatbot_slug' => $conversation->chatbot_slug,
            'chatbot_name' => $conversation->chatbot_name,
            'domain_slug' => $conversation->domain_slug,
            'user_reference' => $conversation->user_reference,
            'user_role' => $conversation->user_role,
            'title' => $conversation->title,
            'status' => $conversation->status,
            'sensitivity' => $conversation->sensitivity,
            'metadata' => $conversation->metadata ?? [],
            'messages_count' => $conversation->messages_count ?? $conversation->messages->count(),
            'messages' => $conversation->relationLoaded('messages')
                ? $conversation->messages->map(fn ($message): array => MessageController::serializeMessage($message))->values()
                : [],
            'created_at' => $conversation->created_at?->toISOString(),
            'updated_at' => $conversation->updated_at?->toISOString(),
        ];
    }
}
