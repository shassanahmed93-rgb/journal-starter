import os

from fastapi import FastAPI
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "journal-api")
SERVICE_VERSION = os.getenv("OTEL_SERVICE_VERSION", "0.1.0")
OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")

resource = Resource.create(
    {
        "service.name": SERVICE_NAME,
        "service.version": SERVICE_VERSION,
        "deployment.environment.name": os.getenv("DEPLOYMENT_ENVIRONMENT", "local"),
    }
)
tracer_provider = TracerProvider(resource=resource)
metric_readers = []
if OTLP_ENDPOINT:
    insecure = OTLP_ENDPOINT.startswith("http://")
    tracer_provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP_ENDPOINT, insecure=insecure))
    )
    metric_readers.append(
        PeriodicExportingMetricReader(OTLPMetricExporter(endpoint=OTLP_ENDPOINT, insecure=insecure))
    )
meter_provider = MeterProvider(resource=resource, metric_readers=metric_readers)

trace.set_tracer_provider(tracer_provider)
metrics.set_meter_provider(meter_provider)

tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
request_counter = meter.create_counter(
    "journal_api_http_requests_total",
    description="HTTP requests handled by the Journal API",
    unit="1",
)
server_error_counter = meter.create_counter(
    "journal_api_http_5xx_total",
    description="HTTP requests that returned a server error",
    unit="1",
)
request_duration = meter.create_histogram(
    "journal_api_http_request_duration_seconds",
    description="Duration of HTTP requests handled by the Journal API",
    unit="s",
)


def instrument_app(app: FastAPI) -> None:
    FastAPIInstrumentor.instrument_app(
        app,
        tracer_provider=tracer_provider,
        meter_provider=meter_provider,
    )


def record_request(status_code: int, route: str, duration_seconds: float) -> None:
    attributes = {
        "http.route": route,
        "http.response.status_code": status_code,
    }
    request_counter.add(1, attributes)
    request_duration.record(duration_seconds, attributes)
    if status_code >= 500:
        server_error_counter.add(1)
