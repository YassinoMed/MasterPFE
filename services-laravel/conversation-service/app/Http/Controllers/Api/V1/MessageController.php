<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMessageRequest;
use App\Models\Conversation;
use App\Models\Message;
use App\Services\ConversationService;
use Illuminate\Http\JsonResponse;

class MessageController extends Controller
{
    public function index(Conversation $conversation): JsonResponse
    {
        return response()->json([
            'data' => $conversation->messages()->get()->map(fn (Message $message): array => self::serializeMessage($message)),
        ]);
    }

    public function store(StoreMessageRequest $request, Conversation $conversation, ConversationService $service): JsonResponse
    {
        $message = $service->appendMessage($conversation, $request->validated());

        return response()->json([
            'data' => self::serializeMessage($message),
            'conversation' => [
                'uuid' => $conversation->uuid,
                'messages_count' => $conversation->messages()->count(),
            ],
        ], 201);
    }

    public static function serializeMessage(Message $message): array
    {
        return [
            'uuid' => $message->uuid,
            'sender' => $message->sender,
            'body' => $message->body,
            'citations' => $message->citations ?? [],
            'safety_flags' => $message->safety_flags ?? [],
            'created_at' => $message->created_at?->toISOString(),
        ];
    }
}
