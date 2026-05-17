# mindami.site

Hugo site for https://www.mindami.com/.

## Initial GitHub Pages Setup

1. Push this repository to GitHub with default branch `main`.
2. In repository settings, open Pages and set Source to GitHub Actions.
3. Ensure workflow file `.github/workflows/hugo.yaml` exists on `main`.
4. Add required repository secrets:
   - `EXTERNAL_REPO_PAT` for private external app repos (for example `alee/ziejazz`).
5. Trigger the `Build and deploy` workflow (push to `main` or manual dispatch).
6. Confirm deployment URL from the `deploy` job output.

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

- `EXTERNAL_REPO_PAT`: GitHub PAT with least-privilege read access to source repos

GitHub Actions passes this secret to the staging script in
`.github/workflows/hugo.yaml`.

### Local Commands

- `make external-apps`: stage external apps using Dockerized Node.js builds
- `make build`: stages external apps first, then runs Hugo production build
- `make pages`: same as build plus `.nojekyll`

Use `make external-apps-host` only if your host already has the required Node/npm
toolchain.

### Troubleshooting

- Missing secret for private repo: set `EXTERNAL_REPO_PAT`
- Missing output directory: verify `output_dir` matches app build output
- Build command failure: run the app's install/build commands in its repo to debug
