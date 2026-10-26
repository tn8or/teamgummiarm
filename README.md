# teamgummiarm.dk

Team Gummiarm Racing #393, in Danish. Hugo (theme bilberry), served by nginx in a container. See `AGENTS.md` for the build details.

## Publishing a post

1. Add the post as a page bundle: `content/posts/<slug>/index.md` plus its images.
2. Open a PR. Add the `staging` label to preview it on https://staging.teamgummiarm.dk/ (future-dated posts are included there).
3. Merge when it's approved. The merge does not have to wait for the publishing day.
4. The post goes live at 08:00 Copenhagen time on its `date`: a scheduled build of `main` runs every morning and pushes `:latest`. A post merged on or after its date goes live with that merge.

`date` is read in Europe/Copenhagen, so `date = '2026-11-05'` means 5 November. To publish now or rebuild by hand, run the CI workflow from the Actions tab (workflow_dispatch on `main`).

GitHub turns off scheduled workflows in a repo with no activity for 60 days. If posts stop going live, re-enable the CI workflow in the Actions tab.

## Front matter rules

CI runs `scripts/lint-front-matter.py` before the build and fails with the file and rule. Every non-draft post needs:

- `description`: present, at most 155 characters. It is the text under the link on social media.
- `tags`: exactly one series tag. The series are listed in `data/tags.toml` (here only `motorcycles`); add a new series there, plus `content/tags/<tag>/_index.md` with its Danish display title. Topic tags (`leadership`, `lessons-learned`, `ai-in-practice`) are optional.
- `date`: present and a valid date (`'2026-11-05'`) or date-time.

Run it locally with `python3 scripts/lint-front-matter.py`.

## Images

- Put images in the post's bundle and reference them by file name. They are served resized (WebP, `srcset`), and link to a full-size copy capped at 3000px on the long edge, without EXIF/GPS. Raw originals are not published.
- og:image (the social preview) is automatic: a 1200x630 crop of the first image in the post. Set `ogAnchor = 'Top'` (or `Center`, `Bottom`, `TopLeft`, ...; default `Smart`) to move the crop. To pick the image yourself, set `images = ['cover.jpg']`; that wins and is used as is. Posts without images use the avatar.

## Staging

PR builds use `https://staging.teamgummiarm.dk/` as baseURL, include future-dated posts and are `noindex`. Only PRs with the `staging` label push `ghcr.io/tn8or/teamgummiarm:staging`, so an unlabelled PR doesn't overwrite another PR's preview.
