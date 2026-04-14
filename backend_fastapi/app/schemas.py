from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

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
    attachments: list[AttachmentOut] = Field(default_factory=list)


class WellVariableOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    slot: int
    label: str
    tag: str
    rawUnit: str
    value: float | str | None = None
    sampleAt: datetime | None = None
    configured: bool = True


class DashboardCoreOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    well: str
    job: str
    latestSampleAt: datetime | None = None
    latestSampleAgeSeconds: int | None = None
    staleThresholdSeconds: int
    variables: list[WellVariableOut] = Field(default_factory=list)


class AlertsListOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    latestAlertAt: datetime | None = None
    limit: int
    alerts: list[AlertOut] = Field(default_factory=list)


class DashboardOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    well: str
    job: str
    latestSampleAt: datetime | None = None
    latestSampleAgeSeconds: int | None = None
    staleThresholdSeconds: int
    variables: list[WellVariableOut]
    alerts: list[AlertOut]


class DashboardDiagnosticsOut(BaseModel):
    cacheStatus: str
    kpCacheStatus: str
    samplesSource: str
    samplesMissingTags: int
    samplesMissingRatio: float
    samplesResolutionMs: float
    samplesFallbackUsed: bool
    samplesFallbackBlocked: bool
    configuredVariables: int


class TrendPointOut(BaseModel):
    timestamp: datetime
    value: float


class TrendResponseOut(BaseModel):
    tag: str
    rawUnit: str = ''
    points: list[TrendPointOut] = Field(default_factory=list)


class AttachmentsResponseOut(BaseModel):
    attachments: list[AttachmentOut] = Field(default_factory=list)


class HealthResponse(BaseModel):
    status: str


class HealthDetailsResponse(BaseModel):
    status: str
    dbStatus: str
    staleThresholdSeconds: int
    latestSampleAt: datetime | None = None
    latestSampleAgeSeconds: int | None = None
    latestSampleSource: str = 'UNKNOWN'
