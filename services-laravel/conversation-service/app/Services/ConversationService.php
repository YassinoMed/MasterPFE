<?php

namespace App\Services;

use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Arr;

class ConversationService
{
    public function list(array $filters = []): LengthAwarePaginator
    {
        return Conversation::query()
            ->withCount('messages')
            ->when($filters['user_reference'] ?? null, fn ($query, $user) => $query->where('user_reference', $user))
            ->when($filters['chatbot_slug'] ?? null, fn ($query, $chatbot) => $query->where('chatbot_slug', $chatbot))
            ->when($filters['status'] ?? null, fn ($query, $status) => $query->where('status', $status))
            ->latest()
            ->paginate((int) ($filters['per_page'] ?? 15));
    }

    public function create(array $data): Conversation
    {
        $initialMessage = Arr::pull($data, 'initial_message');
        $conversation = Conversation::query()->create($data + [
            'status' => Conversation::STATUS_OPEN,
            'sensitivity' => 'medium',
        ]);

        if ($initialMessage) {
            $this->appendMessage($conversation, [
                'sender' => Message::SENDER_USER,
                'body' => $initialMessage,
                'generate_mock_answer' => true,
            ]);
        }

        return $conversation->load('messages');
    }

    public function appendMessage(Conversation $conversation, array $data): Message
    {
        $message = $conversation->messages()->create([
            'sender' => $data['sender'] ?? Message::SENDER_USER,
            'body' => $data['body'],
            'citations' => $data['citations'] ?? [],
            'safety_flags' => $data['safety_flags'] ?? [],
        ]);

        if (($data['generate_mock_answer'] ?? true) && $message->sender === Message::SENDER_USER) {
            $conversation->messages()->create([
                'sender' => Message::SENDER_ASSISTANT,
                'body' => $this->mockAssistantReply($conversation),
                'citations' => [
                    ['title' => 'Source demo', 'confidence' => 0.91],
                ],
                'safety_flags' => [
                    'mode' => 'demo',
                    'rag_real' => false,
                ],
            ]);
        }

        return $message->fresh();
    }

    public function updateStatus(Conversation $conversation, string $status): Conversation
    {
        $conversation->update(['status' => $status]);

        return $conversation->fresh('messages');
    }

    private function mockAssistantReply(Conversation $conversation): string
    {
        return sprintf(
            'Reponse demo generee pour %s. Le moteur RAG reel est hors perimetre de cette version.',
            $conversation->chatbot_name,
        );
    }
}
