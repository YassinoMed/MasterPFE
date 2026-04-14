<?php

namespace App\Http\Requests\Concerns;

trait AuthorizesServiceRequest
{
    protected function authorizeServiceRequest(): bool
    {
        if (app()->environment('testing') && $this->authzFlag('SECURERAG_AUTHZ_ALLOW_TESTING', true)) {
            return true;
        }

        if (app()->environment('local') && $this->authzFlag('SECURERAG_AUTHZ_ALLOW_LOCAL', false)) {
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

    private function authzFlag(string $name, bool $default): bool
    {
        $value = $_SERVER[$name] ?? $_ENV[$name] ?? getenv($name);

        if ($value === false || $value === null) {
            $value = env($name, $default);
        }

        return filter_var($value, FILTER_VALIDATE_BOOL);
    }
}
