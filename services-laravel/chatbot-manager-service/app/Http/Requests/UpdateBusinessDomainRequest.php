<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateBusinessDomainRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
    }

    public function rules(): array
    {
        $domainId = $this->route('domain')?->id;

        return [
            'name' => ['sometimes', 'required', 'string', 'max:120'],
            'slug' => ['sometimes', 'required', 'string', 'max:100', 'regex:/^[a-z0-9-]+$/', Rule::unique('business_domains', 'slug')->ignore($domainId)],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'status' => ['sometimes', Rule::in(['active', 'inactive'])],
        ];
    }
}
