<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\ComplianceEvidence;
use App\Models\SecurityIncident;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class SecurityAuditService
{
    public function incidents(array $filters = []): LengthAwarePaginator
    {
        return SecurityIncident::query()
            ->when($filters['severity'] ?? null, fn ($query, $severity) => $query->where('severity', $severity))
            ->when($filters['status'] ?? null, fn ($query, $status) => $query->where('status', $status))
            ->when($filters['source'] ?? null, fn ($query, $source) => $query->where('source', $source))
            ->latest('detected_at')
            ->paginate((int) ($filters['per_page'] ?? 15));
    }

    public function createIncident(array $data): SecurityIncident
    {
        return SecurityIncident::query()->create($data + [
            'status' => SecurityIncident::STATUS_OPEN,
            'detected_at' => now(),
        ]);
    }

    public function updateIncidentStatus(SecurityIncident $incident, array $data): SecurityIncident
    {
        $incident->update([
            'status' => $data['status'],
            'resolved_at' => $data['resolved_at'] ?? ($data['status'] === SecurityIncident::STATUS_CLOSED ? now() : $incident->resolved_at),
        ]);

        return $incident->fresh();
    }

    public function auditLogs(array $filters = []): LengthAwarePaginator
    {
        return AuditLog::query()
            ->when($filters['actor_reference'] ?? null, fn ($query, $actor) => $query->where('actor_reference', $actor))
            ->when($filters['resource_type'] ?? null, fn ($query, $resource) => $query->where('resource_type', $resource))
            ->latest('occurred_at')
            ->paginate((int) ($filters['per_page'] ?? 20));
    }

    public function createAuditLog(array $data): AuditLog
    {
        return AuditLog::query()->create($data + [
            'actor_type' => 'user',
            'outcome' => 'success',
            'occurred_at' => now(),
        ]);
    }

    public function evidence(array $filters = []): LengthAwarePaginator
    {
        return ComplianceEvidence::query()
            ->when($filters['control_id'] ?? null, fn ($query, $control) => $query->where('control_id', $control))
            ->when($filters['status'] ?? null, fn ($query, $status) => $query->where('status', $status))
            ->latest('collected_at')
            ->paginate((int) ($filters['per_page'] ?? 20));
    }

    public function createEvidence(array $data): ComplianceEvidence
    {
        return ComplianceEvidence::query()->create($data + [
            'collected_at' => now(),
        ]);
    }
}
