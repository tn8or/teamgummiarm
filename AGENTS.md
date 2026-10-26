# Agent guide: teamgummiarm

Hugo site for teamgummiarm.dk: the Team Gummiarm race team site, in Danish, theme Bilberry (`themes/bilberry-hugo-theme`). The front page lists all posts newest first (7 per page, `params.paginate`); top nav is built from root pages like `content/about.md` (`[[menu.main]]` is ignored by the theme). `params.author` must be a table (`{ name, email }`): the theme's RSS template reads `.Author.email` and fails on a string. The theme's `baseof.html` prints the same param straight into `<meta name="author">`, so that tag renders as `map[email:… name:…]`; not overridden here to avoid shadowing the submodule's `baseof.html`.

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
- Tags: everything here is in the `motorcycles` series, so every post gets `tags = ['motorcycles']`, plus an optional topic tag only where it clearly fits (`lessons-learned`, `leadership`, `ai-in-practice`). Same scheme as tommyeriksen.dk (documented in itsaplan, context doc 8). The theme shows tags in the article footer; `content/tags/<tag>/_index.md` sets the Danish display title (`motorcycles` = "Motorcykler", `lessons-learned` = "Erfaringer").
- The site is intentionally near-empty. Don't add content unless asked.

## Build and deploy

- `hugo --minify` must succeed before pushing. CI also builds the container and smoke-tests it.
- The theme links CSS/JS with absolute `baseURL` URLs, so a build for another host needs that baseURL. The `Dockerfile` takes a `STAGING_URL` build arg (empty = production from `hugo.toml`); CI sets it to `https://staging.teamgummiarm.dk/` for PR builds, which also adds `--buildFuture` and `params.staging` (noindex meta via `layouts/partials/hooks/head-end.html`, `Disallow: /` in robots.txt).
- Front matter: every non-draft post needs `description` (max 155 chars), exactly one series tag and a valid `date`. `scripts/lint-front-matter.py` checks it in CI; the series list is `data/tags.toml`. Rules are in `README.md`.
- Date-based publishing: `buildFuture = false`, `timeZone = 'Europe/Copenhagen'`. A future-dated post merged to `main` goes live with the scheduled morning build (08:00 Copenhagen) on its date.
- `layouts/_markup/render-image.html` resolves post-relative image paths (page bundles) so images also work in the post bodies shown on the front page, serves bundle images resized (WebP, `srcset`, lazy) and links them to a full-size copy capped at 3000px (EXIF dropped); remote images, SVG and GIF render as a plain img. Posts have `build.publishResources = false` (cascade in `hugo.toml`), so raw bundle files are only published when a template uses them.
- `layouts/partials/_funcs/get-page-images.html` overrides Hugo's embedded partial so every page gets `og:image`: front matter `images` first (wider than 1200px becomes a 1200px JPEG), else a 1200x630 crop of the first bundle image in the body (anchor from front matter `ogAnchor`, default Smart), else `params.images` in `hugo.toml`. `hooks/head-end.html` adds `og:image:width`/`height`. The avatar fallback is mounted from `static/images/` into `assets/` (`[[module.mounts]]` in `hugo.toml`) so it can be resized.
- The `Dockerfile` accepts a `GIT_COMMIT` build arg and exposes it as `HUGO_PARAMS_commit`, but CI does not pass it yet and no layout uses it.
- CI runs on a self-hosted runner. A push to `main`, the morning schedule (cron 06:00 and 07:00 UTC; a gate job runs only the one that is 08:00 in Copenhagen) and a manual run push `:latest`, which is what goes live. **Merging to `main` deploys teamgummiarm.dk.** Only PRs from this repo with the `staging` label push `:staging`.
- Never push to `main` directly; work via PR.
- Renovate auto-merges Hugo, Docker image, Actions and submodule bumps. Keep the Hugo version in `Dockerfile` and `.github/workflows/ci.yml` in sync.
