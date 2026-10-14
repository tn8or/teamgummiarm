# Agent guide: teamgummiarm

Hugo site for teamgummiarm.dk: the Team Gummiarm race team site, in Danish, theme Bilberry (`themes/bilberry-hugo-theme`). The front page lists all posts newest first (7 per page, `params.paginate`); top nav is built from root pages like `content/about.md` (`[[menu.main]]` is ignored by the theme). The theme's RSS template reads `params.author` as a table, so leave `params.author` unset.

## How work is coordinated

Work on this repo is tracked in itsaplan project `WEBS` (MCP: https://itsaplan-api.tommyeriksen.dk/mcp), shared by Claude (label `claude`) and Cursor (label `cursor`). At the start of a session, read the WEBS doc **"Agent coordination rules"** and follow it; it wins if it differs from this file.

- Knowledge lives only in this repo (code-level docs: this file, plus a `docs/` folder if one is added) or in itsaplan (tasks, plans, decisions, notes). Never only in an agent's local memory, scratch files or chat.
- All work has a WEBS issue. Create one first if none exists.
- Only take `unstarted` issues carrying your own label. Claim by re-reading the issue and moving it to `started`. An issue in `started` is owned; leave it alone.
- When blocked on anything (Tommy, a review, another issue, CI), add the label `waiting` and comment "Waiting on: who/what, and what exactly is needed". Remove it when unblocked.
- Notes, findings and questions go as comments on the issue.
- One issue gives one branch and one PR. Branch names, PR titles and commits start with `WEBS-N`.
- Done → `completed`, abandoned → `canceled`. Never leave an issue `started` after stopping.

## The site

- Hugo 0.167.0 extended. The theme is a git submodule under `themes/`; clone with `--recurse-submodules`.
- Multi-stage `Dockerfile`: Hugo builds the site, nginx serves it (config in `nginx/`).
- Content: posts in `content/posts/`, page bundles for posts with images (`content/posts/<slug>/index.md` + images). TOML front matter (`+++`) with date, title, draft.
- The site is intentionally near-empty. Don't add content unless asked.

## Build and deploy

- `hugo --minify` must succeed before pushing. CI also builds the container and smoke-tests it.
- The `Dockerfile` accepts a `GIT_COMMIT` build arg and exposes it as `HUGO_PARAMS_commit`, but CI does not pass it yet and no layout uses it.
- CI runs on a self-hosted runner. PRs from branches in this repo build and push `ghcr.io/tn8or/teamgummiarm:staging` (fork PRs build but don't push); a push to `main` pushes `:latest`, which is what goes live. **Merging to `main` deploys teamgummiarm.dk.**
- Never push to `main` directly; work via PR.
- Renovate auto-merges Hugo, Docker image, Actions and submodule bumps. Keep the Hugo version in `Dockerfile` and `.github/workflows/ci.yml` in sync.
