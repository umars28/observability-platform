# External Secrets Operator

Pulls secrets from external stores (Vault, AWS Secrets Manager, GCP Secret Manager, Bitwarden, Doppler, etc.) into Kubernetes `Secret` resources.

## Why

- Secrets live in one place, versioned & audited.
- Cluster stores no long-lived credentials — only the token to reach the secret store.
- Rotating a credential does not require redeploying manifests.

## Setup checklist

1. Install ESO via `bootstrap.sh` (already done if you ran that).
2. Create a `ClusterSecretStore` pointing to your secret backend of choice — see the example files in this directory.
3. Reference secrets from platform values via `ExternalSecret` objects.

## Local dev

Not used locally. `bootstrap.sh` skips ESO for `CLUSTER=local`; local values files reference in-cluster MinIO with plaintext credentials.
