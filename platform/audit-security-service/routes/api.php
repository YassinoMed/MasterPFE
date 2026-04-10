<?php

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', function () {
        return response()->json([
            'service' => 'audit-security-service',
            'status' => 'ok',
        ]);
    });

    // GET /audit-logs
    // GET /security-events
    // GET /security-events/{event}
    // GET /incidents
    // POST /admin-actions
    // POST /blocked-responses
});
