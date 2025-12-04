# Contributing

Thanks for your interest! Please follow these steps.

## Workflow
1. Fork the repo and create a branch: `git checkout -b feat/your-change`
2. Run linters and tests locally (PSScriptAnalyzer for PowerShell).
3. Commit and open a Pull Request against `main`.

## Local Development
To spin up a local development environment with n8n and Jenkins:
1. Ensure Docker Desktop is installed and running.
2. Run `.\setup-dev-env.ps1` in PowerShell.
3. Access n8n at `http://localhost:5678` and Jenkins at `http://localhost:8080`.

## Pull request checklist
- [ ] Code compiles and passes static checks.
- [ ] No secrets in the commit.
- [ ] Documentation updated if behavior changed.

## Communication
- Use issues for bugs and feature requests.
- Use Discussions for Q&A (if enabled).

