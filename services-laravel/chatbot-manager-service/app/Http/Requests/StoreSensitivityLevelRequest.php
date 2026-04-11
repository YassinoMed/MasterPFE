<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreSensitivityLevelRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
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
