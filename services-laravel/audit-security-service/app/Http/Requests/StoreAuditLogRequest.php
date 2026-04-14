<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAuditLogRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
    }

    public function rules(): array
    {
        return [
            'actor_type' => ['nullable', 'string', 'max:80'],
            'actor_reference' => ['required', 'string', 'max:180'],
            'action' => ['required', 'string', 'max:160'],
            'resource_type' => ['required', 'string', 'max:120'],
            'resource_id' => ['nullable', 'string', 'max:180'],
            'outcome' => ['nullable', Rule::in(['success', 'failure', 'blocked'])],
            'ip_address' => ['nullable', 'ip'],
            'user_agent' => ['nullable', 'string', 'max:1000'],
            'metadata' => ['nullable', 'array'],
            'occurred_at' => ['nullable', 'date'],
        ];
    }
}
