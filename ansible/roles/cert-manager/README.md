# cert-manager Role

## Purpose

Deploy and configure cert-manager for automated TLS certificate management using Let's Encrypt DNS-01 challenge with provider-agnostic DNS integration.

## Requirements

- k3s cluster deployed and operational
- DNS provider credentials (Cloudflare, Route53, DigitalOcean, Google Cloud DNS, etc.)
- Domain names under your control for DNS-01 validation

## Role Tasks

### Installation (T019, T034)

- Installs cert-manager CRDs
- Deploys cert-manager controllers
- Creates DNS provider secret
- Configures staging and production ClusterIssuers

### DNS-01 Provider Support (T020, T035, FR-017)

- **Cloudflare**: API token
- **AWS Route53**: Access key and secret
- **DigitalOcean**: Access token
- **Google Cloud DNS**: Service account JSON
- **Generic**: Webhook-based solver for other providers

### Idempotent Updates (T034, T035)

- Uses `kubectl apply` for state convergence
- Updates ClusterIssuers when DNS provider credentials change
- Verifies issuer readiness before completing

## Role Variables

### Required (from group_vars/all.yml)

```yaml
cert_manager_enabled: true
cert_manager_email: "admin@example.com"
cert_manager_dns_provider: "cloudflare"  # Options: cloudflare, route53, digitalocean, google
cert_manager_dns_provider_credentials:
  api_token: "your-cloudflare-api-token"  # Cloudflare example
```

### Optional

```yaml
# Set in ansible/group_vars/all.yml as canonical source
cert_manager_version: "{{ cert_manager_version }}"
cert_manager_staging_issuer: "letsencrypt-staging"
cert_manager_production_issuer: "letsencrypt-production"
```

### Provider-Specific Credentials

#### Cloudflare
```yaml
cert_manager_dns_provider_credentials:
  api_token: "your-api-token"
```

#### AWS Route53
```yaml
cert_manager_dns_provider_credentials:
  access_key_id: "AKIAIOSFODNN7EXAMPLE"
  secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  region: "us-east-1"
```

#### DigitalOcean
```yaml
cert_manager_dns_provider_credentials:
  access_token: "your-do-token"
```

#### Google Cloud DNS
```yaml
cert_manager_dns_provider_credentials:
  project: "my-project-id"
  service_account_json: "{{ lookup('file', 'service-account.json') }}"
```

## Dependencies

- k3s-server role (cluster must be operational)

## Example Playbook

```yaml
- hosts: k3s_servers[0]
  roles:
    - role: cert-manager
      when: cert_manager_enabled | default(false)
```

## Usage Example

After deployment, create a certificate:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls-secret
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  dnsNames:
  - example.com
  - www.example.com
```

## Verification

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuers
kubectl get clusterissuer

# Verify issuer is ready
kubectl describe clusterissuer letsencrypt-production

# Test certificate request
kubectl get certificate
kubectl describe certificate example-tls
```

## Tags

- `install`: Run installation tasks
- `cert-manager`: Run all cert-manager tasks
- `certificates`: Alias for cert-manager

## Security Notes

- Store DNS credentials in Ansible Vault
- Use restrictive API tokens (DNS-only permissions)
- Test with staging issuer first to avoid rate limits

## References

- [cert-manager Documentation](https://cert-manager.io/)
- [DNS-01 Challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Feature Specification FR-005, FR-017](../../../specs/001-k3s-ansible-baseline/spec.md)
