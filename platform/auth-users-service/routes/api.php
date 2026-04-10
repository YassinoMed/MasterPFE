<?php

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', function () {
        return response()->json([
            'service' => 'auth-users-service',
            'status' => 'ok',
        ]);
    });

    // Public auth endpoints
    // POST /auth/login
    // POST /auth/refresh
    // POST /auth/logout
    // POST /auth/forgot-password

    // Protected user endpoints
    // GET /me
    // PATCH /me
    // GET /users
    // POST /users
    // GET /roles
    // GET /permissions
});
