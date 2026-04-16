<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'service' => 'audit-security-service',
        'status' => 'ok',
        'api' => '/api/v1',
    ]);
});
