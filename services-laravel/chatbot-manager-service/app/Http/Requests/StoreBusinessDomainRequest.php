<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreBusinessDomainRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'slug' => ['required', 'string', 'max:100', 'regex:/^[a-z0-9-]+$/', 'unique:business_domains,slug'],
            'description' => ['nullable', 'string', 'max:500'],
            'status' => ['nullable', Rule::in(['active', 'inactive'])],
        ];
    }
}
