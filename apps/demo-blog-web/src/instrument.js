// OpenTelemetry bootstrap — must be required before any app code.
// Uses auto-instrumentation for HTTP + Express; adds custom metric hooks in index.js.
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { BatchLogRecordProcessor, LoggerProvider } from '@opentelemetry/sdk-logs';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME, ATTR_SERVICE_NAMESPACE } from '@opentelemetry/semantic-conventions';
import Pyroscope from '@grafana/pyroscope-nodejs';

const serviceName = process.env.OTEL_SERVICE_NAME || 'demo-blog-web';
const tenant = process.env.TENANT || '_default';
const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://alloy.observability.svc:4317';
const pyroscopeEndpoint = process.env.PYROSCOPE_ENDPOINT || 'http://pyroscope.observability.svc:4040';

const headers = { 'x-scope-orgid': tenant };
const resource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: serviceName,
  [ATTR_SERVICE_NAMESPACE]: tenant,
  'deployment.environment': process.env.APP_ENV || 'local',
});

// ─── Metrics + Traces via NodeSDK ─────────────────────────────────────────
const sdk = new NodeSDK({
  resource,
  traceExporter: new OTLPTraceExporter({ url: otlpEndpoint, headers }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: otlpEndpoint, headers }),
    exportIntervalMillis: 10_000,
  }),
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': { enabled: false }, // noisy
  })],
});
sdk.start();

// ─── Logs (separate LoggerProvider since NodeSDK doesn't wire it yet) ────
const loggerProvider = new LoggerProvider({ resource });
loggerProvider.addLogRecordProcessor(
  new BatchLogRecordProcessor(new OTLPLogExporter({ url: otlpEndpoint, headers })),
);
globalThis.otelLoggerProvider = loggerProvider;

// ─── Continuous profiling ────────────────────────────────────────────────
try {
  Pyroscope.init({
    serverAddress: pyroscopeEndpoint,
    appName: serviceName,
    tenantID: tenant,
    tags: { env: process.env.APP_ENV || 'local' },
  });
  Pyroscope.start();
} catch (e) {
  console.warn('pyroscope init failed', e);
}

// ─── Shutdown ────────────────────────────────────────────────────────────
process.on('SIGTERM', async () => {
  try { await sdk.shutdown(); } catch {}
  try { await loggerProvider.shutdown(); } catch {}
  process.exit(0);
});
