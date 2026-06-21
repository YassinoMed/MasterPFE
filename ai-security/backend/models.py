import datetime
from sqlalchemy import Column, Integer, String, Float, Text, DateTime
from .db import Base


class AnalysisResult(Base):
    __tablename__ = "analysis_results"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    source = Column(String(100), index=True)
    classification = Column(String(50), index=True)  # NORMAL, SUSPICIOUS, MALICIOUS
    severity = Column(String(50), index=True)        # LOW, MEDIUM, HIGH, CRITICAL
    confidence = Column(Float)
    explanation = Column(Text)
    recommendation = Column(Text)
    raw_log = Column(Text)


class SecurityIncident(Base):
    __tablename__ = "security_incidents"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    source = Column(String(100), index=True)
    severity = Column(String(50), index=True)
    confidence = Column(Float)
    description = Column(Text)
    recommendation = Column(Text)
    status = Column(String(50), default="OPEN", index=True)  # OPEN, INVESTIGATING, RESOLVED
