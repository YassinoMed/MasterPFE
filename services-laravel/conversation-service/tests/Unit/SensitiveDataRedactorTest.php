<?php

namespace Tests\Unit;

use App\Support\SensitiveDataRedactor;
use Tests\TestCase;

class SensitiveDataRedactorTest extends TestCase
{
    public function test_sanitize_metadata_removes_password_field(): void
    {
        $input = [
            'username' => 'john',
            'password' => 'secret123',
            'email' => 'john@example.com',
        ];

        $result = SensitiveDataRedactor::sanitizeMetadata($input);

        $this->assertArrayHasKey('username', $result);
        $this->assertArrayHasKey('email', $result);

        if (array_key_exists('password', $result)) {
            $this->assertNotEquals('secret123', $result['password']);
        }
    }

    public function test_sanitize_metadata_handles_nested_arrays(): void
    {
        $input = [
            'user' => [
                'name' => 'Alice',
                'token' => 'abc123secret',
            ],
        ];

        $result = SensitiveDataRedactor::sanitizeMetadata($input);

        $this->assertArrayHasKey('user', $result);
    }

    public function test_sanitize_metadata_handles_null_input(): void
    {
        $result = SensitiveDataRedactor::sanitizeMetadata(null);

        $this->assertNull($result);
    }

    public function test_sanitize_metadata_handles_empty_array(): void
    {
        $result = SensitiveDataRedactor::sanitizeMetadata([]);

        $this->assertIsArray($result);
        $this->assertEmpty($result);
    }
}
