# mindami.site

Hugo site for https://www.mindami.com/.

## Initial GitHub Pages Setup

1. Push this repository to GitHub with default branch `main`.
2. In repository settings, open Pages and set Source to GitHub Actions.
3. Ensure workflow file `.github/workflows/hugo.yml` exists on `main`.
4. Add required repository secrets:
   - `ZIEJAZZ_REPO_PAT` for private `alee/ziejazz` source access.
5. Trigger the `Build and deploy` workflow (push to `main` or manual dispatch).
6. Confirm deployment URL from the `deploy` job output.

## PR-Ready Deployment Checklist

1. Workflow file is present at `.github/workflows/hugo.yml` and deploys from `main`.
2. Repository Pages setting is `Source: GitHub Actions`.
3. Required secret is configured:
   - `ZIEJAZZ_REPO_PAT` (used for private `alee/ziejazz` source access).
4. Custom domain file exists at `static/CNAME` and currently contains `www.mindami.com`.
5. DNS is configured for `www.mindami.com` to point at GitHub Pages.
6. A production run of `Build and deploy` is green on `main`.
7. Post-deploy smoke checks pass:
   - `https://www.mindami.com/`
   - `https://www.mindami.com/blog/`
   - `https://www.mindami.com/apps/ziejazz/`

## External JS/TS App Deployments

This site can build JS/TS apps from other GitHub repositories and publish their
build artifacts under this site's static paths.

Current seeded app:
- `alee/ziejazz` published at `/apps/ziejazz/`

### How It Works

1. External app build definitions live in `external-apps.conf`.
2. `scripts/stage_external_apps.sh` clones/builds each app and stages artifacts
   into `static/<publish_subpath>/`.
3. Hugo includes those files automatically in `public/` during site build.

### Config Format

File: `external-apps.conf`

Pipe-delimited fields:

`slug|repo|ref|install_cmd|build_cmd|output_dir|publish_subpath|auth`

- `slug`: unique app id
- `repo`: GitHub `owner/repo`, HTTPS URL, or SSH URL
- `ref`: branch/tag/commit-ish
- `install_cmd`: install command run in app root
- `build_cmd`: build command run in app root
- `output_dir`: build output directory relative to app root
- `publish_subpath`: destination under `static/`
- `auth`: `none` or `pat`

Example:

```text
ziejazz|alee/ziejazz|main|npm ci|npm run build|dist|apps/ziejazz|pat
```

### Secrets For Private Repos

For entries using `auth=pat`, set repo secret:

- `ZIEJAZZ_REPO_PAT`: GitHub PAT with read access to `alee/ziejazz`

GitHub Actions passes this secret to the staging script in
`.github/workflows/hugo.yml`.

### Local Commands

- `make external-apps`: stage external apps using Dockerized Node.js builds
- `make build`: stages external apps first, then runs Hugo production build
- `make pages`: same as build plus `.nojekyll`

Use `make external-apps-host` only if your host already has the required Node/npm
toolchain.

### Troubleshooting

- Missing secret for private repo: set `ZIEJAZZ_REPO_PAT`
- Missing output directory: verify `output_dir` matches app build output
- Build command failure: run the app's install/build commands in its repo to debug

### Common Failure Modes

- Workflow fails on external repo clone/auth:
   confirm repository secret `ZIEJAZZ_REPO_PAT` exists and has read access to `alee/ziejazz`.
- Workflow deploys successfully but custom domain does not resolve:
   verify `static/CNAME` is `www.mindami.com` and DNS CNAME points to GitHub Pages host.
- Site root loads but nested routes return 404:
   ensure Hugo `baseURL` and `.env` `SITE_URL` are aligned to `https://www.mindami.com/`.
- `/apps/ziejazz/` returns 404:
   confirm external app staging step ran and output was copied into `static/apps/ziejazz/` before Hugo build.
- Manual dispatch builds from non-main branch and should not publish:
   expected behavior; deploy job runs only for `main`.
