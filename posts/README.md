# posts inbox

Drop Markdown files into this folder (for example, `my-note.md`) and push to GitHub.

The GitHub Action `.github/workflows/publish-posts.yml` will:
1. Convert each file to Jekyll format in `_posts/YYYY-MM-DD-slug.md`
2. Add standard front matter (`layout`, `title`, `date`, `categories`)
3. Move the original source file to `posts/processed/`

Date format is generated using `POST_TZ` (default `UTC`) in `scripts/publish_posts.sh`.
