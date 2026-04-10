<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'service' => 'audit-security-service',
        'surface' => 'api-only',
    ]);
});
