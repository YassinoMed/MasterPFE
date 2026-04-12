<?php

namespace App\Policies;

use App\Models\SecurityIncident;

class SecurityIncidentPolicy
{
    public function view(?object $user, SecurityIncident $incident): bool
    {
        return true;
    }

    public function manage(?object $user, SecurityIncident $incident): bool
    {
        return true;
    }
}
