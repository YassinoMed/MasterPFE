<?php

namespace App\Support;

use SecureRag\LaravelSecurity\Support\SensitiveDataRedactor as SharedSensitiveDataRedactor;

final class SensitiveDataRedactor
{
    /**
     * @param  mixed  $value
     * @return mixed
     */
    public static function sanitizeMetadata(mixed $value): mixed
    {
        return SharedSensitiveDataRedactor::sanitizeMetadata($value);
    }
}
