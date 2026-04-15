<?php

namespace App\Support;

use SecureRag\LaravelSecurity\Support\SensitiveDataRedactor as SharedSensitiveDataRedactor;

final class SensitiveDataRedactor
{
    /**
     * @param  mixed  $value
     * @return mixed
     */
    public static function sanitizeForAudit(mixed $value, string $path = ''): mixed
    {
        return SharedSensitiveDataRedactor::sanitizeForAudit($value, $path);
    }
}
