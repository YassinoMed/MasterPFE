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
        return true;
    }

    public function update(User $actor, BusinessDomain $domain): bool
    {
        return true;
    }
}
