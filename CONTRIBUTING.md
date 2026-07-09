# Contributing

Jobmaxxing is local-first software for job-search work. Treat privacy as part of correctness.

## Before You Open A Pull Request

Use a clean checkout or branch of this public repository. Do not develop from a private working app checkout that contains real user data.

Run:

```bash
npm run clean:check
```

Then run the validation commands relevant to the change, such as:

```bash
npm test
npm run lint
npm run typecheck:strict
npm run build
npm run smoke
```

For native macOS changes, also run the native verification that is practical for your machine:

```bash
./script/build_and_run.sh --verify
npm run native:test
```

If any command fails, fix the issue before opening the PR. If a native command fails because of a local toolchain problem, include the exact failure in the PR.

## Data That Must Not Be Committed

Never commit:

- real candidate data, company scans, contacts, application history, interview notes, saved evidence, or generated application material
- resumes, cover letters, PDFs, screenshots, imported documents, email exports, message exports, or browser session data
- API keys, access tokens, cookies, OAuth files, `.env` files, local databases, logs, or machine-specific config
- `data/`, `output/`, `dist/`, `macos/dist/`, `macos/.build/`, `node_modules/`, coverage folders, or generated artifacts
- old Git history copied from a private checkout

Tests should use clearly synthetic fixtures with fake names, fake companies, and domains such as `example.com`.

## Pull Request Checklist

Include this checklist in the PR description:

- [ ] I ran `npm run clean:check`.
- [ ] I inspected the full diff for private data, credentials, local paths, generated output, and old private history.
- [ ] I used synthetic fixtures only.
- [ ] I ran the relevant tests and documented any environment-only failures.
- [ ] This change preserves existing user data during updates or migrations.

## Runtime Data

The app should keep user state outside Git history. Feature updates should add behavior, schema support, and migrations without overwriting existing local data.
