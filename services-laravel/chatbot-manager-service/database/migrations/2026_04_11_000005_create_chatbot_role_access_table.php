<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chatbot_role_access', function (Blueprint $table) {
            $table->id();
            $table->foreignId('chatbot_id')->constrained()->cascadeOnDelete();
            $table->string('role_slug')->index();
            $table->boolean('is_allowed')->default(true);
            $table->timestamps();
            $table->unique(['chatbot_id', 'role_slug']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chatbot_role_access');
    }
};
