# PaglaMLX Documentation Site

This website is built using [Docusaurus](https://docusaurus.io/) and deployed to GitHub Pages from the `docs/` directory whenever `main` changes.

## Local development

```bash
npm ci
npm run start
```

## Build

```bash
npm run build
```

The generated static content is written to `build/`. The Pages workflow overlays `static/index.html` as the public landing page and publishes the result.

## Current release

**PaglaMLX v1.6.0** is the current stable release. The public site describes the native Swift + Swift-NIO runtime, the C-compatible bridge to MLX C++, and macOS Keychain-backed credential storage.

- [v1.6.0 release notes](https://github.com/paglaai/PaglaMLX/releases/tag/v1.6.0)
- [Native architecture](docs/architecture.md)
- [Project roadmap](https://github.com/paglaai/PaglaMLX/blob/main/ROADMAP.md)
- [Repository](https://github.com/paglaai/PaglaMLX)

## Deployment

The GitHub Actions workflow in `.github/workflows/deploy-docs.yml` runs `npm ci`, builds Docusaurus, copies the static landing page and API reference, and deploys the artifact with GitHub Pages.

## Runtime note

PaglaMLX v1.6.0 does not require a Python gateway, FastAPI, Uvicorn, or `mlx_lm.server` process at runtime.
