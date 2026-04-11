<?php

use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\PermissionController;
use App\Http\Controllers\Api\V1\RoleController;
use App\Http\Controllers\Api\V1\UserController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', HealthController::class);

    Route::apiResource('users', UserController::class)->except(['destroy']);
    Route::patch('/users/{user}/status', [UserController::class, 'status']);
    Route::post('/users/{user}/roles', [UserController::class, 'roles']);

    Route::apiResource('roles', RoleController::class)->except(['destroy']);
    Route::get('/permissions', PermissionController::class);
});
