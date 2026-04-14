<?php

namespace App\Policies;

use App\Models\Chatbot;
use App\Models\User;

class ChatbotPolicy
{
    public function viewAny(?User $actor): bool
    {
        return true;
    }

    public function view(?User $actor, Chatbot $chatbot): bool
    {
        return $chatbot->visibility !== 'restricted' || $actor !== null;
    }

    public function create(User $actor): bool
    {
        return $this->canManageChatbots($actor);
    }

    public function update(User $actor, Chatbot $chatbot): bool
    {
        return $this->canManageChatbots($actor);
    }

    public function changeStatus(User $actor, Chatbot $chatbot): bool
    {
        return $this->canManageChatbots($actor);
    }

    private function canManageChatbots(User $actor): bool
    {
        return in_array($actor->email, $this->platformAdminEmails(), true);
    }

    /**
     * @return array<int, string>
     */
    private function platformAdminEmails(): array
    {
        $raw = (string) env('SECURERAG_PLATFORM_ADMIN_EMAILS', 'admin@example.local,security@example.local');

        return array_values(array_filter(array_map('trim', explode(',', $raw))));
    }
}
