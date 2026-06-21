<?php

use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\ComplianceEvidenceController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\SecurityIncidentController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', HealthController::class);

    Route::middleware('throttle:120,1')->group(function (): void {
        Route::apiResource('incidents', SecurityIncidentController::class)->only(['index', 'store', 'show']);
        Route::patch('/incidents/{incident}/status', [SecurityIncidentController::class, 'status']);
        Route::get('/audit-logs', [AuditLogController::class, 'index']);
        Route::post('/audit-logs', [AuditLogController::class, 'store']);
        Route::get('/compliance-evidence', [ComplianceEvidenceController::class, 'index']);
        Route::post('/compliance-evidence', [ComplianceEvidenceController::class, 'store']);
    });
});
