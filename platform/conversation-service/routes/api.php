<?php

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', function () {
        return response()->json([
            'service' => 'conversation-service',
            'status' => 'ok',
        ]);
    });

    // GET /conversations
    // POST /conversations
    // GET /conversations/{conversation}
    // GET /conversations/{conversation}/messages
    // POST /conversations/{conversation}/messages
    // GET /conversations/{conversation}/security-status
});
