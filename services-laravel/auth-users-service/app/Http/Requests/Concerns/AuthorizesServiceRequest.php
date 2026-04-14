<?php

namespace App\Http\Requests\Concerns;

trait AuthorizesServiceRequest
{
    protected function authorizeServiceRequest(): bool
    {
        if (app()->environment(['local', 'testing']) && env('SECURERAG_AUTHZ_ALLOW_LOCAL', true)) {
            return true;
        }

        $sharedToken = (string) env('SECURERAG_SHARED_API_TOKEN', '');
        if ($sharedToken === '') {
            return false;
        }

        $headerToken = (string) $this->header('X-SecureRAG-Service-Token', '');
        if ($headerToken !== '' && hash_equals($sharedToken, $headerToken)) {
            return true;
        }

        $bearerToken = (string) $this->bearerToken();

        return $bearerToken !== '' && hash_equals($sharedToken, $bearerToken);
    }
}
