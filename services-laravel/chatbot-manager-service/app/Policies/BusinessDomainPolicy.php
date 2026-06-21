<?php

namespace App\Policies;

use App\Models\BusinessDomain;
use App\Models\User;

class BusinessDomainPolicy
{
    public function viewAny(?User $actor): bool
    {
        return true;
    }

    public function view(?User $actor, BusinessDomain $domain): bool
    {
        return true;
    }

    public function create(User $actor): bool
    {
        return $this->canManageCatalog($actor);
    }

    public function update(User $actor, BusinessDomain $domain): bool
    {
        return $this->canManageCatalog($actor);
    }

    private function canManageCatalog(User $actor): bool
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
