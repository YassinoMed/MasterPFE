<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreComplianceEvidenceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'control_id' => ['required', 'string', 'max:120'],
            'title' => ['required', 'string', 'max:180'],
            'status' => ['required', Rule::in(['pass', 'warn', 'fail', 'not_applicable'])],
            'evidence_uri' => ['nullable', 'string', 'max:500'],
            'summary' => ['nullable', 'string', 'max:5000'],
            'collected_at' => ['nullable', 'date'],
            'metadata' => ['nullable', 'array'],
        ];
    }
}
