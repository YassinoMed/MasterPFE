<?php

namespace App\Support;

final class SensitiveDataRedactor
{
    /**
     * @var array<int, string>
     */
    private const SENSITIVE_KEY_PATTERNS = [
        '/(^|_|-)(prompt|raw_prompt|system_prompt|user_prompt)($|_|-)/i',
        '/(^|_|-)(message|body|question|input_text|payload)($|_|-)/i',
    ];

    /**
     * @param  mixed  $value
     * @return mixed
     */
    public static function sanitizeForAudit(mixed $value, string $path = ''): mixed
    {
        if (is_array($value)) {
            $sanitized = [];
            foreach ($value as $key => $nestedValue) {
                $keyString = (string) $key;
                $childPath = $path === '' ? $keyString : "{$path}.{$keyString}";
                if (self::looksSensitiveKey($keyString)) {
                    $sanitized[$key] = self::redactedPayload($nestedValue);

                    continue;
                }

                $sanitized[$key] = self::sanitizeForAudit($nestedValue, $childPath);
            }

            return $sanitized;
        }

        return $value;
    }

    private static function looksSensitiveKey(string $key): bool
    {
        foreach (self::SENSITIVE_KEY_PATTERNS as $pattern) {
            if (preg_match($pattern, $key) === 1) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param  mixed  $value
     * @return array<string, int|string|true>
     */
    private static function redactedPayload(mixed $value): array
    {
        $encoded = is_scalar($value) || $value === null
            ? (string) $value
            : json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: 'unserializable';

        return [
            'redacted' => true,
            'sha256' => hash('sha256', $encoded),
            'length' => strlen($encoded),
        ];
    }
}
