# GitHub Actions Workflows

This directory contains automated CI/CD workflows for the ML model deployment.

## 🚀 Quick Start

1. **Set up secrets** in GitHub repository settings:
   - `DOCKER_USERNAME` and `DOCKER_PASSWORD` (or `GITHUB_TOKEN` for GHCR)
   - `KUBE_CONFIG` (base64-encoded kubeconfig file)

2. **Push to main branch** to trigger automatic deployment

3. **Read full documentation**: [WORKFLOWS.md](WORKFLOWS.md)

## 📁 Workflows

| Workflow | File | Purpose | Trigger |
|----------|------|---------|---------|
| CI/CD Pipeline | `ci-cd.yml` | Full automation | Push, PR, Manual |
| PR Checks | `pr-checks.yml` | Test PRs | Pull Request |
| Manual Retrain | `manual-retrain.yml` | Retrain model | Manual |
| Rollback | `rollback.yml` | Rollback deployment | Manual |

## 🔗 Links

- [Complete Setup Guide](WORKFLOWS.md)
- [Project README](../README.md)
- [Kubernetes Manifests](../k8s/)

## 💡 Need Help?

See [WORKFLOWS.md](WORKFLOWS.md) for detailed setup instructions and troubleshooting.
