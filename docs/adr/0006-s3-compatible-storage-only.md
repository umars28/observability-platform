# ADR-0006: S3-compatible object storage as the only backend

- **Status**: Accepted
- **Date**: 2026-07-19

## Context

Mimir/Loki/Tempo/Pyroscope all support multiple backends (S3, GCS, Azure Blob, Swift, filesystem). Supporting each first-class multiplies the values files, testing surface, and documentation load.

## Decision

Configure every component with the **S3-compatible backend only**. Users on other clouds should:

- **AWS**: use S3 directly
- **Cloudflare**: use R2 (S3-compatible)
- **GCP**: enable GCS S3 interoperability mode
- **Azure**: front Azure Blob with MinIO gateway (deprecated), or use AWS S3 cross-cloud
- **Self-hosted / air-gapped**: MinIO

## Alternatives considered

- **Support each backend natively**
  - Pros: no interop layer for GCS/Azure users
  - Cons: 4× the values files, 4× the docs, 4× the testing
- **File-system backend for portability**
  - Pros: no external dependency
  - Cons: not durable at scale; loses the biggest win of the LGTMP design (cheap object storage)

## Consequences

- **Positive**: one storage abstraction across four components. Config surface is tiny (endpoint, bucket, credentials, region). Any S3-compatible service works.
- **Negative**: GCS users go through the interop shim (some feature loss). Azure users need an extra hop or must migrate to S3.
- **Neutral**: MinIO is the standard "just make S3 work" solution when a native backend isn't available.

## Follow-ups

- Document the exact env vars used to configure storage across all components in a single place (in `kubernetes/platform/README.md`).
