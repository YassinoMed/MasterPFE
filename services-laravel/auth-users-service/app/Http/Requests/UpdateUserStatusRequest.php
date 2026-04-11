<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateUserStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in(['active', 'inactive', 'locked', 'pending_activation'])],
            'reason' => ['nullable', 'string', 'max:240'],
        ];
    }
}
