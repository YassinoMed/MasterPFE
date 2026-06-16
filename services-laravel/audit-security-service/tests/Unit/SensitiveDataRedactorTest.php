<?php

namespace Tests\Unit;

use App\Support\SensitiveDataRedactor;
use Tests\TestCase;

class SensitiveDataRedactorTest extends TestCase
{
    public function test_sanitize_for_audit_redacts_passwords(): void
    {
        $input = [
            'username' => 'admin',
            'password' => 'super-secret',
            'role' => 'admin',
        ];

        $result = SensitiveDataRedactor::sanitizeForAudit($input);

        $this->assertIsArray($result);
        // Password should be redacted, not stored in plain text
        if (array_key_exists('password', $result)) {
            $this->assertNotEquals('super-secret', $result['password']);
        }
    }

    public function test_sanitize_for_audit_handles_scalar(): void
    {
        $result = SensitiveDataRedactor::sanitizeForAudit('plain text');

        $this->assertEquals('plain text', $result);
    }

    public function test_sanitize_for_audit_with_path_context(): void
    {
        $result = SensitiveDataRedactor::sanitizeForAudit(['secret' => 'value'], '/api/v1/login');

        $this->assertIsArray($result);
    }

    public function test_sanitize_for_audit_handles_null(): void
    {
        $result = SensitiveDataRedactor::sanitizeForAudit(null);

        $this->assertNull($result);
    }
}
