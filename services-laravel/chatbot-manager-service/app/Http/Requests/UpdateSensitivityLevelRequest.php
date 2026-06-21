<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateSensitivityLevelRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
    }

    public function rules(): array
    {
        $levelId = $this->route('level')?->id;

        return [
            'name' => ['sometimes', 'required', 'string', 'max:120'],
            'slug' => ['sometimes', 'required', 'string', 'max:100', 'regex:/^[a-z0-9-]+$/', Rule::unique('sensitivity_levels', 'slug')->ignore($levelId)],
            'rank' => ['sometimes', 'required', 'integer', 'min:1', 'max:99', Rule::unique('sensitivity_levels', 'rank')->ignore($levelId)],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
        ];
    }
}
