<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;

class StoreSensitivityLevelRequest extends FormRequest
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
            'slug' => ['required', 'string', 'max:100', 'regex:/^[a-z0-9-]+$/', 'unique:sensitivity_levels,slug'],
            'rank' => ['required', 'integer', 'min:1', 'max:99', 'unique:sensitivity_levels,rank'],
            'description' => ['nullable', 'string', 'max:500'],
        ];
    }
}
