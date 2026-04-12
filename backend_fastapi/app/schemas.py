from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

Severity = Literal['OK', 'ATTENTION', 'CRITICAL']


class AttachmentOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    name: str
    url: str
    mimeType: str = ''
    sizeBytes: int | None = None
    createdAt: datetime | None = None


class AlertOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str
    description: str
    severity: Severity
    createdAt: datetime
    attachmentsCount: int = 0
    attachments: list[AttachmentOut] = []


class WellVariableOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    slot: int
    label: str
    tag: str
    rawUnit: str
    value: float | str | None = None
    sampleAt: datetime | None = None
    configured: bool = True


class DashboardOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    well: str
    job: str
    latestSampleAt: datetime | None = None
    staleThresholdSeconds: int
    variables: list[WellVariableOut]
    alerts: list[AlertOut]


class TrendPointOut(BaseModel):
    timestamp: datetime
    value: float


class TrendResponseOut(BaseModel):
    tag: str
    rawUnit: str = ''
    points: list[TrendPointOut]


class AttachmentsResponseOut(BaseModel):
    attachments: list[AttachmentOut]


class HealthResponse(BaseModel):
    status: str
