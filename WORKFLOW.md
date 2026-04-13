# Professional Deployment Workflow

## Overview
This repository follows a Git workflow with three main branches and feature branches for organized development and deployment.

## Branch Structure

### Main Branches

#### `main` (Production)
- **Purpose**: Production-ready code
- **Protection**: Only accept merges from `staging` via Pull Requests
- **Requirement**: All tests must pass and code reviewed
- **Release**: Tagged with semantic versioning (v1.0.0, v1.0.1, etc.)
- **Deployment**: Automatically deployed to production environment

#### `staging`
- **Purpose**: Pre-production testing and validation
- **Protection**: Only accept merges from `dev` via Pull Requests
- **Requirement**: All tests must pass, integration testing required
- **QA**: User acceptance testing (UAT) performed on this branch
- **Deployment**: Automatically deployed to staging environment

#### `dev`
- **Purpose**: Integration branch for completed features
- **Protection**: Only accept merges from feature branches via Pull Requests
- **Requirement**: Code review and passing tests required
- **Testing**: Continuous integration tests run on every merge
- **Deployment**: Deployed to development environment

### Feature Branches

#### Format: `feat/<feature-name>`
- **Source**: Branch off from `dev`
- **Naming**: Use single descriptive word: `feat/cnn`, `feat/fusion`, `feat/edge`, `feat/mobile-app`
- **Commits**: Use conventional commits format: `feat(scope): description`
- **Scope examples**: `cnn`, `fusion`, `edge`, `mobile`, `api`

Example:
```bash
git checkout dev
git checkout -b feat/mobile-app
# ... make changes ...
git commit -m "feat(mobile): implement camera integration"
git push -u origin feat/mobile-app
# Create Pull Request to merge into dev
```

#### Format: `fix/<issue-name>`
- **Source**: Branch off from `dev` or `main` (if hotfix needed)
- **Naming**: Use single descriptive word: `fix/auth`, `fix/inference`
- **Commits**: Use format: `fix(scope): description`

## Workflow Process

### 1. Feature Development
```
main → (checkout dev) → (checkout -b feat/feature-name) → make changes → push
```

**Steps:**
1. Ensure you're on the latest `dev` branch
   ```bash
   git checkout dev
   git pull origin dev
   ```
2. Create feature branch
   ```bash
   git checkout -b feat/your-feature
   ```
3. Make commits with proper messages
   ```bash
   git commit -m "feat(scope): add new capability"
   ```
4. Push feature branch
   ```bash
   git push -u origin feat/your-feature
   ```
5. Create Pull Request on GitHub with:
   - Clear description of changes
   - Reference any related issues
   - Screenshots/demos for UI changes
6. Request code review from team members
7. Address review feedback with additional commits

### 2. Feature Integration into Dev
- PR reviewed and approved
- All CI tests pass
- Merge into `dev` branch
- Feature branch deleted after merge
- Changes deployed to development environment

### 3. Release to Staging
```
dev → pull request → staging
```

**When ready for pre-production testing:**
1. Team confirms features in `dev` are ready
2. Create Pull Request from `dev` to `staging`
3. Run full integration test suite
4. Deploy to staging environment
5. QA and UAT performed
6. Document any issues for backlog

### 4. Release to Production
```
staging → pull request → main (tagged release)
```

**When staging is validated:**
1. All UAT tests pass
2. Create Pull Request from `staging` to `main`
3. Run final production test suite
4. Marketing/release notes prepared
5. Merge to `main`
6. Create release tag: `git tag -a vX.Y.Z -m "Release message" && git push origin vX.Y.Z`
7. Deploy to production

## Commit Message Format

All commits should follow the Conventional Commits specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation
- **style**: Code style (no behavioral change)
- **refactor**: Code refactoring
- **perf**: Performance improvement
- **test**: Adding/updating tests
- **chore**: Build, dependencies, etc.

### Examples
```
feat(cnn): enhance Phase 1 model with improved data loading
fix(fusion): resolve tensor dimension mismatch in ensemble layer
docs(readme): update installation instructions
refactor(edge): optimize TFLite inference performance
```

## Special Cases

### Hotfixes (Production Bugs)
```bash
git checkout main
git checkout -b fix/critical-issue
# fix the issue
git commit -m "fix(scope): critical production fix"
git push -u origin fix/critical-issue
# Create PR to main
# After merge: also merge back to dev and staging
git checkout dev && git merge fix/critical-issue
git push
git checkout staging && git merge fix/critical-issue
git push
```

### Emergency Rollback
```bash
git checkout main
git revert <commit-sha>  # Don't use reset on shared branches!
git push
```

## Protected Branch Rules (GitHub Settings)

Recommended rules for all main branches (`main`, `staging`, `dev`):

- ✅ Require pull request reviews (at least 1)
- ✅ Dismiss stale pull request approvals
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Restrict who can push to matching branches (admins only)
- ✅ Include administrators in restrictions
- ✅ Allow auto-merge (squash recommended for features)

## Local Development Setup

```bash
# Clone repository
git clone https://github.com/ahmaddev-codex/maize-disease-detection.git
cd maize-disease-detection

# Create tracking branches for all main branches
git checkout -b dev origin/dev
git checkout -b staging origin/staging

# Configure your local repo
git config --local pull.rebase false  # Use merge when pulling
```

## Useful Commands

```bash
# Update all branches
git fetch origin
git branch -v

# Delete local branch
git branch -d feat/feature-name

# Delete remote feature branch after PR merged
git push origin --delete feat/feature-name

# See what changed in your feature
git diff dev...feat/your-feature

# Squash commits before PR
git rebase -i dev

# Sync fork with upstream (if applicable)
git fetch upstream
git merge upstream/main
git push origin main
```

## CI/CD Integration

Each branch triggers different deployment pipelines:

| Branch | Tests | Linting | Build | Deploy |
|--------|-------|---------|-------|--------|
| Feature | ✅ | ✅ | ✅ | ❌ |
| `dev` | ✅ | ✅ | ✅ | ✅ Dev |
| `staging` | ✅ | ✅ | ✅ | ✅ Staging |
| `main` | ✅ | ✅ | ✅ | ✅ Production |

## Troubleshooting

### Accidentally committed to wrong branch?
```bash
git cherry-pick <commit-sha>  # Copy commit to correct branch
git reset --soft HEAD~1      # Remove from wrong branch (keeps changes)
```

### Need to update feature branch from latest dev?
```bash
git fetch origin
git rebase origin/dev
git push -f origin feat/your-feature
```

### PR conflicts with dev/staging?
```bash
git fetch origin
git merge origin/dev      # Resolve conflicts locally
git push origin feat/your-feature
```

## References
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Branching Model](https://nvie.com/posts/a-successful-git-branching-model/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
