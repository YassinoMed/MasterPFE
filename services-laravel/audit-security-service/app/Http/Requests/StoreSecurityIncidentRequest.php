<?php

namespace App\Http\Requests;

use App\Models\SecurityIncident;
use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreSecurityIncidentRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:180'],
            'severity' => ['required', Rule::in([
                SecurityIncident::SEVERITY_LOW,
                SecurityIncident::SEVERITY_MEDIUM,
                SecurityIncident::SEVERITY_HIGH,
                SecurityIncident::SEVERITY_CRITICAL,
            ])],
            'status' => ['nullable', Rule::in([
                SecurityIncident::STATUS_OPEN,
                SecurityIncident::STATUS_TRIAGED,
                SecurityIncident::STATUS_MITIGATED,
                SecurityIncident::STATUS_CLOSED,
            ])],
            'source' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:5000'],
            'detected_at' => ['nullable', 'date'],
            'metadata' => ['nullable', 'array'],
        ];
    }
}
