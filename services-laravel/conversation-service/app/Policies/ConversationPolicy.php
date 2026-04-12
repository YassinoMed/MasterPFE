<?php

namespace App\Policies;

use App\Models\Conversation;

class ConversationPolicy
{
    public function view(?object $user, Conversation $conversation): bool
    {
        return true;
    }

    public function manage(?object $user, Conversation $conversation): bool
    {
        return true;
    }
}
