<?php

namespace App\Policies;

use App\Models\Conversation;

class ConversationPolicy
{
    public function view(?object $user, Conversation $conversation): bool
    {
        return $this->isConversationOwner($user, $conversation) || $this->hasSecurityRole($user);
    }

    public function manage(?object $user, Conversation $conversation): bool
    {
        return $this->isConversationOwner($user, $conversation) || $this->hasSecurityRole($user);
    }

    private function isConversationOwner(?object $user, Conversation $conversation): bool
    {
        if ($user === null) {
            return false;
        }

        $reference = $user->email ?? $user->reference ?? null;

        return $reference !== null && hash_equals((string) $conversation->user_reference, (string) $reference);
    }

    private function hasSecurityRole(?object $user): bool
    {
        if ($user === null) {
            return false;
        }

        $role = $user->role ?? $user->role_slug ?? null;

        return in_array($role, ['super-admin', 'admin-plateforme', 'admin-securite'], true);
    }
}
