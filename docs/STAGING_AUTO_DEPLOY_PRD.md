# VPS Staging Auto-Deploy PRD

**Status:** Proposed / needs review before implementation  
**Owner:** Turgay  
**Project:** psy.market  
**Target environment:** VPS staging at `https://psy.heyturgay.com`  
**Created:** 2026-06-27

---

## 1. Problem

The psy.market production deployment on Vercel updates automatically when GitHub `main` changes, but the VPS staging environment behind `psy.heyturgay.com` currently requires manual rebuild/restart steps.

This creates confusion and stale staging behavior:

- GitHub/Vercel may already contain a change.
- The VPS checkout may have the same source change but an older `.next` build or running process.
- Cloudflare/domain routing may show the VPS staging server, not Vercel.
- Multiple people/agents can push to `main`, but staging does not automatically pick those commits up.

Staging should behave more like Vercel: any accepted push to `main` should update the running VPS staging app automatically.

---

## 2. Goals

1. Automatically deploy VPS staging when `turyildiz/psy` receives a push to `main`.
2. Deploy commits regardless of who pushed them: Turgay, Hermes, teammates, or merges.
3. Keep production Vercel behavior unchanged.
4. Avoid exposing a custom public deployment endpoint unless necessary.
5. Keep secrets out of the repo.
6. Make deployment logs easy to inspect.
7. Ensure only one staging deploy runs at a time.
8. Make the staging server reflect GitHub `main` exactly, or explicitly document any deviation.

---

## 3. Non-goals

- Do not replace Vercel production deployment.
- Do not add a public admin UI.
- Do not run database migrations automatically in this first version.
- Do not deploy branches other than `main` unless explicitly added later.
- Do not solve rollback automation beyond documenting the rollback path.

---

## 4. Recommended Solution

Use **GitHub Actions SSH deployment**.

Flow:

```text
push to turyildiz/psy main
→ GitHub Actions workflow starts
→ workflow SSHes into VPS
→ VPS updates /home/repos/psy to origin/main
→ VPS runs npm run build
→ VPS restarts the running Next app/systemd service
→ psy.heyturgay.com serves the new build
```

This is preferred over a VPS webhook listener because it avoids exposing a new deploy endpoint and gives deploy logs directly in GitHub Actions.

---

## 5. Alternatives Considered

### Option A — GitHub Actions SSH Deploy (Recommended)

**Pros**

- Triggers for every `main` push, regardless of pusher.
- No public deploy webhook endpoint on the VPS.
- Logs are visible in GitHub Actions.
- Simple to reason about.
- Uses GitHub as the source of truth.

**Cons**

- Requires an SSH private key stored as a GitHub repo secret.
- Requires careful VPS SSH/user permissions.
- Deploy success depends on GitHub Actions availability.

### Option B — VPS Webhook Listener

Run a lightweight Node/Python listener on the VPS, exposed through Cloudflare tunnel or nginx, and validate GitHub `X-Hub-Signature-256`.

**Pros**

- GitHub only calls an HTTP endpoint.
- No GitHub Actions SSH key required.

**Cons**

- Public deploy endpoint must be secured and monitored.
- Requires custom listener service.
- Requires Cloudflare/nginx routing.
- More moving parts than GitHub Actions.

### Option C — VPS Polling Timer

A systemd timer periodically checks GitHub for new `main` commits and deploys if changed.

**Pros**

- No public endpoint.
- No GitHub Actions SSH key.
- VPS controls its own deployment.

**Cons**

- Not instant.
- Polling GitHub forever.
- Less visible than GitHub Actions.

---

## 6. Proposed GitHub Actions Workflow

Create:

```text
.github/workflows/deploy-staging.yml
```

Initial workflow shape:

```yaml
name: Deploy VPS staging

on:
  push:
    branches:
      - main

concurrency:
  group: staging-deploy
  cancel-in-progress: false

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy on VPS
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          port: ${{ secrets.VPS_PORT }}
          script: |
            set -euo pipefail
            cd /home/repos/psy
            git fetch origin main
            git reset --hard origin/main
            npm run build
            fuser -k 3030/tcp || true
```

### Notes

- `concurrency` prevents overlapping staging deploys.
- `git reset --hard origin/main` makes staging a clean deployment checkout.
- `fuser -k 3030/tcp || true` matches the current project restart pattern where `psy.service` restarts the app.
- If the service should be restarted directly instead, replace with a systemd command after confirming the service scope/name.

---

## 7. Required GitHub Secrets

Configure these under:

```text
GitHub repo → Settings → Secrets and variables → Actions → Repository secrets
```

Required:

| Secret | Purpose |
|---|---|
| `VPS_HOST` | VPS hostname/IP reachable from GitHub Actions |
| `VPS_USER` | SSH user that owns/can deploy `/home/repos/psy` |
| `VPS_SSH_KEY` | Private SSH key with access to the VPS |
| `VPS_PORT` | SSH port, usually `22` |

Optional:

| Secret | Purpose |
|---|---|
| `VPS_DEPLOY_PATH` | Avoid hardcoding `/home/repos/psy` in the workflow |

No secret values should be committed to the repo.

---

## 8. VPS Requirements

The deploy user on the VPS must be able to run:

```bash
cd /home/repos/psy
git fetch origin main
git reset --hard origin/main
npm run build
fuser -k 3030/tcp
```

The VPS checkout should either:

1. be treated as disposable deployment state, or
2. avoid local uncommitted changes that conflict with `git reset --hard`.

Current local `.agent-context/*` edits show why this decision matters. If staging is deployment state, local uncommitted changes should not live there long-term.

---

## 9. Deployment Strategy Decision: `reset --hard` vs `pull --ff-only`

### Recommended for staging: `git reset --hard origin/main`

Use when staging should exactly match GitHub `main`.

Benefits:

- Avoids hidden local edits.
- Avoids merge commits on the VPS.
- Makes staging reproducible.

Risk:

- Discards uncommitted tracked local changes in `/home/repos/psy`.

### Safer but less clean: `git pull --ff-only origin main`

Use when local uncommitted changes must be preserved.

Benefits:

- Does not discard tracked local edits automatically.

Risks:

- Deploy can fail if the worktree is dirty.
- Staging may drift from GitHub.

---

## 10. Restart Strategy

Current project notes use:

```bash
fuser -k 3030/tcp
```

and expect `psy.service` to restart the Next process.

Before implementation, confirm whether the preferred restart command should be:

```bash
fuser -k 3030/tcp || true
```

or a direct systemd command, such as:

```bash
systemctl --user restart psy.service
```

or, if the service is system-wide:

```bash
sudo systemctl restart psy.service
```

If `sudo` is needed, configure a very narrow sudoers rule for only this service restart. Do not give broad passwordless sudo.

---

## 11. Acceptance Criteria

1. A push to `main` triggers a GitHub Actions workflow.
2. The workflow SSHes into the VPS successfully.
3. The VPS checkout updates to the pushed commit.
4. `npm run build` succeeds on the VPS.
5. The running staging app restarts after the build.
6. `https://psy.heyturgay.com` serves the new commit after deploy.
7. Failed deploys are visible in GitHub Actions logs.
8. Secrets are stored only in GitHub Actions secrets and/or VPS environment, never committed.
9. Concurrent pushes do not run overlapping builds.

---

## 12. Verification Plan

After implementation:

1. Push a harmless copy-only commit to `main`.
2. Confirm GitHub Actions starts automatically.
3. Watch the workflow logs.
4. Confirm the workflow reports success.
5. On the VPS, verify:

```bash
cd /home/repos/psy
git rev-parse HEAD
```

matches GitHub `main`.

6. Confirm the local build exists:

```bash
cat /home/repos/psy/.next/BUILD_ID
```

7. Confirm the staging page reflects the test change.
8. Revert the test change if needed and confirm the revert auto-deploys too.

---

## 13. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Bad commit breaks staging | GitHub Actions logs show failure; revert commit and push |
| Local VPS edits are lost | Treat staging as deployment state; keep planning docs committed or outside deploy checkout |
| SSH key leak | Store only in GitHub secrets; use a deploy-only key/user |
| Deploys overlap | Use GitHub Actions `concurrency` |
| Build succeeds but app does not restart | Prefer explicit service restart after confirming service scope |
| Node/npm environment differs in non-interactive SSH | Use absolute paths or source the needed shell profile if required |
| GitHub Actions cannot reach VPS SSH | Confirm firewall allows SSH from GitHub Actions or use a self-hosted runner/tunnel alternative |

---

## 14. Open Questions

1. Should staging deployments use `git reset --hard origin/main` or `git pull --ff-only origin main`?
2. Should restart use `fuser -k 3030/tcp` or a systemd restart command?
3. Which Linux user should GitHub Actions SSH in as?
4. Should `/home/repos/psy` remain a mixed development/deployment checkout, or should staging use a separate clean path such as `/srv/psy-staging`?
5. Should the workflow run `npm ci` when `package-lock.json` changes?
6. Should successful/failed staging deploy notifications be sent to Telegram later?

---

## 15. Future Enhancements

- Add health check after restart, e.g. curl staging homepage and check status 200.
- Add a rollback workflow that deploys a selected commit SHA.
- Move staging deployment to a separate clean checkout path.
- Add Telegram/Discord notification on deploy success/failure.
- Add conditional `npm ci` when `package-lock.json` changes.
- Add branch preview deployments if needed later.
