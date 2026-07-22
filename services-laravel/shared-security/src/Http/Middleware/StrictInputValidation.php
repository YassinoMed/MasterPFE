<?php

namespace SecureRag\LaravelSecurity\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class StrictInputValidation
{
    /**
     * Handle an incoming request and enforce strict input validation & sanitization.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle(Request $request, Closure $next): Response
    {
        // 1. Block Null-Byte Injection (%00)
        foreach ($request->query() as $key => $value) {
            if (is_string($value) && str_contains($value, "\0")) {
                return response()->json([
                    'error' => 'INVALID_INPUT_NULL_BYTE',
                    'message' => 'Null byte detected in request parameter.',
                ], Response::HTTP_BAD_REQUEST);
            }
        }

        // 2. Enforce length limits on all input strings (Max 10,000 characters per field)
        foreach ($request->all() as $key => $value) {
            if (is_string($value) && strlen($value) > 10000) {
                return response()->json([
                    'error' => 'INPUT_PAYLOAD_TOO_LARGE',
                    'message' => "Field '{$key}' exceeds maximum allowable length of 10000 characters.",
                ], Response::HTTP_REQUEST_ENTITY_TOO_LARGE);
            }
        }

        // 3. Block malicious control characters
        foreach ($request->all() as $key => $value) {
            if (is_string($value) && preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', $value)) {
                return response()->json([
                    'error' => 'INVALID_CONTROL_CHARACTERS',
                    'message' => "Field '{$key}' contains disallowed control characters.",
                ], Response::HTTP_BAD_REQUEST);
            }
        }

        return $next($request);
    }
}
