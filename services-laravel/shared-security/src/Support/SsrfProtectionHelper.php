<?php

namespace SecureRag\LaravelSecurity\Support;

use InvalidArgumentException;

class SsrfProtectionHelper
{
    /**
     * Whitelisted internal hostnames / domains.
     *
     * @var array<string>
     */
    protected static array $allowedHosts = [
        'localhost',
        '127.0.0.1',
        '::1',
        'ollama',
        'qdrant',
        'auth-users',
        'chatbot-manager',
        'conversation-service',
        'audit-security-service',
        'portal-web',
        'postgres',
        'redis',
    ];

    /**
     * Blacklisted metadata / internal sensitive IP ranges (AWS IMDS, GCP metadata, link-local).
     *
     * @var array<string>
     */
    protected static array $blockedIpPrefixes = [
        '169.254.',      # AWS Link-Local / Cloud IMDS (169.254.169.254)
        '100.64.',       # Carrier-grade NAT
        '0.',            # Current network
    ];

    /**
     * Validate an outgoing target URL against SSRF vulnerabilities.
     *
     * @param string $url
     * @throws InvalidArgumentException
     * @return string Validated URL
     */
    public static function validateUrl(string $url): string
    {
        $parts = parse_url($url);

        if (!$parts || empty($parts['host'])) {
            throw new InvalidArgumentException("SSRF Protection: Malformed or missing host in URL: {$url}");
        }

        $host = strtolower($parts['host']);

        // Check cloud metadata endpoints explicitly
        if ($host === '169.254.169.254' || $host === 'metadata.google.internal' || $host === 'instance-data') {
            throw new InvalidArgumentException("SSRF Protection: Access to cloud metadata service is strictly forbidden ({$host}).");
        }

        // Validate IP prefixes
        foreach (self::$blockedIpPrefixes as $prefix) {
            if (str_starts_with($host, $prefix)) {
                throw new InvalidArgumentException("SSRF Protection: Destination IP prefix blocked ({$host}).");
            }
        }

        // Allow Kubernetes service DNS pattern (*.svc.cluster.local) or explicit whitelisted hosts
        $isWhitelisted = false;
        if (str_ends_with($host, '.svc.cluster.local') || str_ends_with($host, '.securerag-hub.svc')) {
            $isWhitelisted = true;
        } else {
            foreach (self::$allowedHosts as $allowed) {
                if ($host === $allowed || str_ends_with($host, '.' . $allowed)) {
                    $isWhitelisted = true;
                    break;
                }
            }
        }

        if (!$isWhitelisted) {
            throw new InvalidArgumentException("SSRF Protection: Host '{$host}' is not in the allowed internal whitelist.");
        }

        return $url;
    }

    /**
     * Get Guzzle / HTTP Client default options with redirects disabled and SSRF protection.
     *
     * @return array<string, mixed>
     */
    public static function getSafeHttpOptions(): array
    {
        return [
            'allow_redirects' => false,
            'connect_timeout' => 5.0,
            'timeout'         => 10.0,
            'verify'          => true,
            'http_errors'     => false,
        ];
    }
}
