<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chatbots', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('name');
            $table->string('slug')->unique();
            $table->text('description')->nullable();
            $table->foreignId('business_domain_id')->constrained()->restrictOnDelete();
            $table->foreignId('sensitivity_level_id')->constrained()->restrictOnDelete();
            $table->string('status')->default('draft')->index();
            $table->string('visibility')->default('restricted')->index();
            $table->string('system_prompt_version')->default('v1');
            $table->string('security_profile')->default('standard');
            $table->boolean('is_active')->default(false)->index();
            $table->json('settings')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chatbots');
    }
};
