<?php

namespace App\Policies;

use App\Models\SecurityIncident;

class SecurityIncidentPolicy
{
    public function view(?object $user, SecurityIncident $incident): bool
    {
        return $this->hasSecurityAccess($user);
    }

    public function manage(?object $user, SecurityIncident $incident): bool
    {
        return $this->hasSecurityAccess($user);
    }

    private function hasSecurityAccess(?object $user): bool
    {
        if ($user === null) {
            return false;
        }

        $role = $user->role ?? $user->role_slug ?? null;
        $permissions = $user->permissions ?? [];

        if (is_string($permissions)) {
            $permissions = array_map('trim', explode(',', $permissions));
        }

        return in_array($role, ['super-admin', 'admin-securite'], true)
            || in_array('security.view', (array) $permissions, true);
    }
}
