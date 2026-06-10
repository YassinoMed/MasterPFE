"""Schémas Pydantic partagés entre l'API et les modules internes."""
from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


# ---------- Enums ----------

class ChatbotDomain(str, Enum):
    HR = "hr"
    IT_SUPPORT = "it_support"


class SensitivityLevel(str, Enum):
    PUBLIC = "public"
    INTERNAL = "internal"
    CONFIDENTIAL = "confidential"


class DocumentType(str, Enum):
    POLICY = "policy"
    PROCEDURE = "procedure"
    FAQ = "faq"
    GUIDE = "guide"


class AttackType(str, Enum):
    PROMPT_INJECTION = "prompt_injection"
    JAILBREAK = "jailbreak"
    EXFILTRATION = "exfiltration"
    ROLE_PLAY = "role_play"
    BYPASS = "bypass"


class AttackSeverity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


# ---------- Internal data structures ----------

class DocumentChunk(BaseModel):
    content: str
    chunk_index: int
    total_chunks: int
    source_document: str
    chatbot_domain: str
    allowed_roles: List[str]
    sensitivity_level: str
    document_type: str
    created_at: str


class RetrievedChunk(BaseModel):
    content: str
    score: float
    source_document: str
    chunk_index: int
    sensitivity_level: str
    document_type: str


class AttackPrompt(BaseModel):
    attack_type: AttackType
    severity: AttackSeverity
    description: str
    example_prompt: str


# ---------- API requests ----------

class IngestRequest(BaseModel):
    file_path: str = Field(..., description="Chemin du fichier à ingérer")
    chatbot_domain: ChatbotDomain
    allowed_roles: List[str] = Field(..., min_length=1)
    sensitivity_level: SensitivityLevel = SensitivityLevel.INTERNAL
    document_type: DocumentType = DocumentType.GUIDE


class SearchRequest(BaseModel):
    query: str = Field(..., min_length=1)
    chatbot_domain: ChatbotDomain
    user_role: str = Field(..., min_length=1)
    top_k: int = Field(default=5, ge=1, le=50)
    score_threshold: float = Field(default=0.7, ge=0.0, le=1.0)


class IngestAttackRequest(BaseModel):
    prompts: List[AttackPrompt] = Field(..., min_length=1)


class SimilarityScoreRequest(BaseModel):
    prompt: str = Field(..., min_length=1)


# ---------- API responses ----------

class IngestResponse(BaseModel):
    status: str
    chunks_created: int
    collection: str
    source_document: str


class SearchResponse(BaseModel):
    results: List[RetrievedChunk]
    total: int
    formatted_context: Optional[str] = None


class IngestAttackResponse(BaseModel):
    status: str
    vectors_added: int


class SimilarityScoreResponse(BaseModel):
    max_score: float
    attack_type: Optional[str] = None
    is_suspicious: bool


class CollectionInfoModel(BaseModel):
    name: str
    vectors_count: int
    points_count: int
    status: str


class CollectionsResponse(BaseModel):
    collections: List[CollectionInfoModel]


class HealthResponse(BaseModel):
    status: str
    qdrant: bool
    model_loaded: bool
    timestamp: datetime = Field(default_factory=datetime.utcnow)
