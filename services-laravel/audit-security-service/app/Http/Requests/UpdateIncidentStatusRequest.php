<?php

namespace App\Http\Requests;

use App\Models\SecurityIncident;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateIncidentStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in([
                SecurityIncident::STATUS_OPEN,
                SecurityIncident::STATUS_TRIAGED,
                SecurityIncident::STATUS_MITIGATED,
                SecurityIncident::STATUS_CLOSED,
            ])],
            'resolved_at' => ['nullable', 'date'],
        ];
    }
}
