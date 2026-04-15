<?php

namespace App\Services;

use App\Support\DemoPortalData;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Throwable;

class PortalBackendClient
{
    private array $sources = [];

    public function users(): array
    {
        return $this->fetchCollection(
            service: 'auth_users',
            path: 'users',
            fallback: DemoPortalData::users(),
            normalizer: fn (array $user): array => [
                'name' => trim(sprintf('%s %s', $user['first_name'] ?? '', $user['last_name'] ?? '')) ?: ($user['name'] ?? 'Utilisateur'),
                'email' => $user['email'] ?? 'non-renseigne@example.test',
                'role' => $this->firstRoleLabel($user),
                'team' => $user['department'] ?? $user['team'] ?? 'Non renseigne',
                'status' => $user['status'] ?? 'inactive',
                'lastLogin' => $user['last_login_at'] ?? $user['lastLogin'] ?? 'Non disponible',
            ],
        );
    }

    public function roles(): array
    {
        return $this->fetchCollection(
            service: 'auth_users',
            path: 'roles',
            fallback: DemoPortalData::roles(),
            normalizer: fn (array $role): array => [
                'name' => $role['label'] ?? $role['name'] ?? 'role',
                'slug' => $role['name'] ?? $role['slug'] ?? null,
                'description' => $role['description'] ?? 'Role metier SecureRAG Hub.',
                'users' => $role['users_count'] ?? $role['users'] ?? 0,
                'permissions' => collect($role['permissions'] ?? [])
                    ->map(fn ($permission) => is_array($permission) ? ($permission['name'] ?? $permission['label'] ?? '') : $permission)
                    ->filter()
                    ->values()
                    ->all(),
            ],
        );
    }

    public function chatbots(): array
    {
        return $this->fetchCollection(
            service: 'chatbot_manager',
            path: 'chatbots',
            fallback: DemoPortalData::chatbots(),
            normalizer: fn (array $chatbot): array => [
                'name' => $chatbot['name'] ?? 'Chatbot',
                'domain' => $chatbot['business_domain']['name'] ?? $chatbot['domain'] ?? 'Domaine non renseigne',
                'sensitivity' => $chatbot['sensitivity_level']['name'] ?? $chatbot['sensitivity'] ?? 'Non classe',
                'status' => $chatbot['status'] ?? 'draft',
                'guardrail' => $chatbot['security_profile'] ?? $chatbot['guardrail'] ?? 'standard',
                'owner' => $chatbot['settings']['owner'] ?? $chatbot['owner'] ?? 'admin-plateforme',
                'modelMode' => $chatbot['settings']['model_mode'] ?? $chatbot['modelMode'] ?? 'mock',
                'temperature' => $chatbot['settings']['temperature'] ?? $chatbot['temperature'] ?? '0.0',
            ],
        );
    }

    public function conversation(): array
    {
        if ($this->mode() === 'mock') {
            $this->markSource('conversation', 'mock', 'mock local', 'Mode mock force pour stabiliser la demonstration.');

            return DemoPortalData::conversation();
        }

        $items = $this->requestData('conversation', 'conversations?per_page=1');
        $conversation = $items[0] ?? null;

        if (! is_array($conversation)) {
            $this->markSource('conversation', 'mock', 'fallback mock', 'Aucune conversation persistante disponible.');

            return DemoPortalData::conversation();
        }

        $details = $this->requestData('conversation', 'conversations/'.($conversation['uuid'] ?? ''));
        $conversation = is_array($details) && isset($details['uuid']) ? $details : $conversation;
        $messages = collect($conversation['messages'] ?? [])
            ->map(fn (array $message): array => [
                'sender' => $message['sender'] ?? 'system',
                'body' => $message['body'] ?? '',
                'time' => isset($message['created_at']) ? substr((string) $message['created_at'], 11, 5) : '--:--',
            ])
            ->values()
            ->all();

        if ($messages === []) {
            $messages = DemoPortalData::conversation()['messages'];
        }

        $this->markSource('conversation', 'api', 'API metier', 'Conversation chargee depuis conversation-service.');

        return [
            'conversation' => [
                'id' => $conversation['uuid'] ?? 'conversation-demo',
                'title' => $conversation['title'] ?? 'Conversation demo',
                'chatbot' => $conversation['chatbot_name'] ?? 'Chatbot',
                'securityStatus' => $conversation['metadata']['security_status'] ?? 'safe',
            ],
            'messages' => $messages,
            'sources' => collect($conversation['messages'] ?? [])
                ->flatMap(fn (array $message) => $message['citations'] ?? [])
                ->map(fn (array $citation): array => [
                    'title' => $citation['title'] ?? 'Source demo',
                    'confidence' => (string) ($citation['confidence'] ?? '0.80'),
                ])
                ->values()
                ->all() ?: DemoPortalData::conversation()['sources'],
            'source' => $this->source('conversation'),
        ];
    }

    public function conversationHistory(): array
    {
        return $this->fetchCollection(
            service: 'conversation',
            path: 'conversations',
            fallback: DemoPortalData::conversationHistory(),
            normalizer: fn (array $conversation): array => [
                'id' => $conversation['uuid'] ?? 'conv-demo',
                'title' => $conversation['title'] ?? 'Conversation',
                'chatbot' => $conversation['chatbot_name'] ?? 'Chatbot',
                'user' => $conversation['user_reference'] ?? 'Utilisateur demo',
                'messages' => $conversation['messages_count'] ?? count($conversation['messages'] ?? []),
                'securityStatus' => $conversation['metadata']['security_status'] ?? 'safe',
                'updatedAt' => isset($conversation['updated_at']) ? substr((string) $conversation['updated_at'], 0, 16) : 'Non disponible',
            ],
        );
    }

    public function securityIncidents(): array
    {
        $fallback = DemoPortalData::securityIncidents();

        if ($this->mode() === 'mock') {
            $this->markSource('audit_security', 'mock', 'mock local', 'Mode mock force pour stabiliser la demonstration.');

            return $fallback + ['source' => $this->source('audit_security')];
        }

        $items = $this->requestData('audit_security', 'incidents');

        if ($items === null) {
            return $fallback + ['source' => $this->source('audit_security')];
        }

        $incidents = collect($items)
            ->map(fn (array $incident): array => [
                'id' => isset($incident['uuid']) ? substr($incident['uuid'], 0, 8) : 'SEC-DEMO',
                'severity' => $incident['severity'] ?? 'medium',
                'type' => $incident['title'] ?? 'incident',
                'status' => $incident['status'] ?? 'open',
                'service' => $incident['source'] ?? 'audit-security-service',
            ])
            ->values()
            ->all();

        $open = collect($incidents)->whereNotIn('status', ['closed'])->count();
        $high = collect($incidents)->whereIn('severity', ['high', 'critical'])->count();

        $this->markSource('audit_security', 'api', 'API metier', 'Incidents charges depuis audit-security-service.');

        return [
            'summary' => [
                ['label' => 'Incidents ouverts', 'value' => $open],
                ['label' => 'Incidents critiques/hauts', 'value' => $high],
                ['label' => 'Sources supervisees', 'value' => collect($incidents)->pluck('service')->unique()->count()],
            ],
            'incidents' => $incidents,
            'source' => $this->source('audit_security'),
        ];
    }

    public function source(string $service): array
    {
        return $this->sources[$service] ?? [
            'mode' => 'mock',
            'label' => 'mock local',
            'message' => 'Le service n a pas encore ete interroge.',
        ];
    }

    private function fetchCollection(string $service, string $path, array $fallback, callable $normalizer): array
    {
        if ($this->mode() === 'mock') {
            $this->markSource($service, 'mock', 'mock local', 'Mode mock force pour stabiliser la demonstration.');

            return $fallback;
        }

        $items = $this->requestData($service, $path);
        if ($items !== null) {
            $this->markSource($service, 'api', 'API metier', 'Donnees chargees depuis le microservice Laravel.');

            return collect($items)
                ->map(fn (array $item): array => $normalizer($item))
                ->values()
                ->all();
        }

        return $fallback;
    }

    private function requestData(string $service, string $path): ?array
    {
        return $this->fetchBackendData($service, $path);
    }

    private function fetchBackendData(string $service, string $path): ?array
    {
        try {
            $response = Http::acceptJson()
                ->timeout($this->timeout())
                ->connectTimeout($this->timeout())
                ->get($this->endpoint($service, $path));

            if ($response->successful()) {
                return $this->extractData($response);
            }

            $this->markSource($service, 'mock', 'fallback mock', sprintf('API indisponible: HTTP %s.', $response->status()));
        } catch (Throwable $exception) {
            if ($this->mode() === 'api') {
                throw $exception;
            }

            $this->markSource($service, 'mock', 'fallback mock', 'API indisponible: '.$exception->getMessage());
        }

        return null;
    }

    private function endpoint(string $service, string $path): string
    {
        $baseUrl = rtrim((string) config("services.secure_rag.{$service}.base_url"), '/');
        $apiBase = str_ends_with($baseUrl, '/api/v1') ? $baseUrl : "{$baseUrl}/api/v1";

        return $apiBase.'/'.ltrim($path, '/');
    }

    private function extractData(Response $response): array
    {
        $payload = $response->json();

        if (is_array($payload) && array_key_exists('data', $payload) && is_array($payload['data'])) {
            return $payload['data'];
        }

        return is_array($payload) ? $payload : [];
    }

    private function firstRoleLabel(array $user): string
    {
        $firstRole = collect($user['roles'] ?? [])->first();

        if (is_array($firstRole)) {
            return $firstRole['label'] ?? $firstRole['name'] ?? 'user';
        }

        return is_string($firstRole) ? $firstRole : ($user['role'] ?? 'user');
    }

    private function mode(): string
    {
        return (string) config('services.secure_rag.mode', 'auto');
    }

    private function timeout(): float
    {
        return (float) config('services.secure_rag.timeout', 0.4);
    }

    private function markSource(string $service, string $mode, string $label, string $message): void
    {
        $this->sources[$service] = compact('mode', 'label', 'message');
    }
}
