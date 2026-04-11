<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chatbot_prompt_configs', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->foreignId('chatbot_id')->constrained()->cascadeOnDelete();
            $table->string('version');
            $table->text('system_prompt');
            $table->boolean('is_current')->default(false)->index();
            $table->text('change_note')->nullable();
            $table->timestamps();
            $table->unique(['chatbot_id', 'version']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chatbot_prompt_configs');
    }
};
