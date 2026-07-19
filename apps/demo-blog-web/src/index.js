// demo-blog-web — Express server serving blog posts about products.
import express from 'express';
import pino from 'pino';
import { metrics, trace } from '@opentelemetry/api';

const app = express();
const port = Number(process.env.PORT || 3000);
const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

const meter = metrics.getMeter('demo-blog-web');
const tracer = trace.getTracer('demo-blog-web');

const requestCounter = meter.createCounter('http_requests_total', {
  description: 'HTTP requests received',
});
const latencyHistogram = meter.createHistogram('http_request_duration_seconds', {
  description: 'HTTP request duration in seconds',
  unit: 's',
});

// ─── Seed data ───────────────────────────────────────────────────────────
const POSTS = {
  'p-1': [
    { product_id: 'p-1', title: 'Why the tactile bump matters', excerpt: 'Blue vs brown switches...' },
    { product_id: 'p-1', title: 'Split-layout ergonomics', excerpt: 'Wrist angles over 8-hour days...' },
  ],
  'p-2': [
    { product_id: 'p-2', title: 'MX Master vs vertical mice', excerpt: 'The RSI trade-off nobody talks about...' },
  ],
  'p-3': [
    { product_id: 'p-3', title: 'One hub or three dongles?', excerpt: 'Charging + display + data over USB-C...' },
  ],
  'p-4': [],
  'p-5': [
    { product_id: 'p-5', title: 'ANC in open-plan offices', excerpt: 'When silence stops helping...' },
  ],
};

// ─── Middleware ──────────────────────────────────────────────────────────
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durSec = Number(process.hrtime.bigint() - start) / 1e9;
    const attrs = {
      route: req.route?.path || req.path,
      method: req.method,
      status: String(res.statusCode),
    };
    requestCounter.add(1, attrs);
    latencyHistogram.record(durSec, attrs);

    const span = trace.getActiveSpan();
    const traceId = span?.spanContext().traceId;
    logger.info({
      route: attrs.route,
      method: req.method,
      status: res.statusCode,
      duration_ms: Math.round(durSec * 1000),
      trace_id: traceId,
    }, 'request');
  });
  next();
});

// ─── Routes ──────────────────────────────────────────────────────────────
app.get('/healthz', (_req, res) => res.status(200).send('ok'));

app.get('/posts', (_req, res) => {
  const all = Object.values(POSTS).flat();
  res.json(all);
});

app.get('/posts/:productId', async (req, res) => {
  const span = tracer.startSpan('blog.PostsFor', {
    attributes: { 'product.id': req.params.productId },
  });

  try {
    // Simulate a slow rendering pipeline for a few products.
    const posts = POSTS[req.params.productId];
    if (!posts) {
      span.end();
      return res.status(404).json({ error: 'no posts for product' });
    }

    // Occasional hotspot: crunching markdown.
    if (Math.random() < 0.05) {
      burnCpu(120);
    }
    await new Promise((r) => setTimeout(r, 10 + Math.random() * 40));

    span.end();
    res.json(posts);
  } catch (err) {
    span.recordException(err);
    span.end();
    res.status(500).json({ error: err.message });
  }
});

function burnCpu(ms) {
  const deadline = Date.now() + ms;
  let x = 0;
  while (Date.now() < deadline) x = (x * 1664525 + 1013904223) >>> 0;
  return x;
}

app.listen(port, () => {
  logger.info({ port }, 'demo-blog-web started');
});
