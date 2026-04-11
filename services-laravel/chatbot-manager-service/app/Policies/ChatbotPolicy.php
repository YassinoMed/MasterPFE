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
        return true;
    }

    public function update(User $actor, Chatbot $chatbot): bool
    {
        return true;
    }

    public function changeStatus(User $actor, Chatbot $chatbot): bool
    {
        return true;
    }
}
