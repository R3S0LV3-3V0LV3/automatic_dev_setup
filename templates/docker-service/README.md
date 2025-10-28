# Docker Service Starter

This template scaffolds a containerised service with Docker and Compose. It pairs well with GitHub’s recommendations for infrastructure-as-code tracked alongside application code.

## Contents
```
docker-service/
├── README.md
├── Dockerfile
├── docker-compose.yml
└── Makefile (optional task automation)
```

## Usage
1. Build and run locally:
   ```bash
   docker compose up --build
   ```
2. Stop and clean resources:
   ```bash
   docker compose down --volumes
   ```
3. Add environment-specific overrides by duplicating `docker-compose.yml` into `docker-compose.override.yml`.

## Best Practices
- Keep application code out of the image build context unless required; use `.dockerignore`.
- Explicitly pin base image tags (`python:3.11-slim`, `node:20-alpine`) to guarantee reproducibility.
- When deploying, mirror the Compose configuration into IaC managed manifests (Helm, Terraform, etc.).
