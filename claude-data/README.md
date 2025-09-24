# Claude Code Session Data

This directory stores Claude Code session data from the development container.

## Purpose
- Maps to `/home/developer/.claude` inside the container
- Preserves conversation history and context across container restarts
- Each developer maintains their own local session data

## Security Measures
- **Excluded from Git**: Listed in `.gitignore` to prevent committing sensitive data
- **Excluded from Docker builds**: Listed in `.dockerignore` to prevent baking sensitive data into Docker images
- **Local only**: This data remains on your local machine and is never shared

## How It Works
1. When you run Claude Code inside the container, it saves session data to `/home/developer/.claude`
2. This directory is volume-mounted to this `claude-data/` directory on your host
3. The data persists even when the container is stopped or rebuilt
4. The data is excluded from both Git commits and Docker image builds

## Important Notes
- Do NOT manually commit files from this directory to Git
- Do NOT share the contents of this directory
- Each developer will have their own unique session data
- Safe to delete if you want to start fresh (container will recreate structure)