# Onboarding

## Prerequisites
- Git
- Docker Desktop (for local development)
- Jenkins admin access (or CI runner)
- n8n cloud account (or local Docker instance)
- OpenAI API key (store in n8n, do not commit)

## Steps
1. Clone repo.
2. **Local Setup**: Run `.\setup-dev-env.ps1` to start n8n and Jenkins locally.
3. Import `templates/n8n-workflows/intake-openai.json` into n8n (Cloud or Local).
4. Review `templates/psadt-template` and `examples/sample-app`.
5. Configure Jenkins credentials and create a Windows agent (or use the local Jenkins instance).
