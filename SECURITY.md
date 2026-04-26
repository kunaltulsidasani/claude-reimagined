# Security Policy

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Use one of these private channels instead:

1. **GitHub Private Vulnerability Reporting** (preferred) — open a report at
   [github.com/kunaltulsidasani/claude-reimagined/security/advisories/new](https://github.com/kunaltulsidasani/claude-reimagined/security/advisories/new).
2. **Email** — contact the maintainer via the email on their [GitHub profile](https://github.com/kunaltulsidasani).

Include in your report:

- A description of the issue and where it lives in the code (file path + line range, or commit SHA).
- Steps to reproduce, ideally with a minimal proof of concept.
- Impact assessment — what could a malicious actor do with this?
- Any mitigations or workarounds you've identified.

## Response Expectations

- **Acknowledgement:** within 7 days.
- **Triage and severity assessment:** within 14 days.
- **Fix or mitigation plan:** within 30 days for high/critical issues; longer for low-severity.

You will be credited in the release notes for the fix unless you ask to remain anonymous.

## Supported Versions

Only the latest tagged release is actively supported. Older tags do not receive security backports.

| Version | Supported |
|---------|-----------|
| Latest tag (`v0.0.x`) | ✅ |
| Older tags | ❌ |

## Scope

In scope:

- Code in this repository: bootstrap and install scripts, hooks, lib/, and configuration.
- The skill registry and how skills are fetched.
- Any code we ship that runs on a user's machine.

Out of scope (report directly to the upstream project):

- Vulnerabilities in [Claude Code](https://github.com/anthropics/claude-code), [RTK](https://github.com/rtk-ai/rtk), [context-mode](https://github.com/mksglu/context-mode), [code-review-graph](https://pypi.org/project/code-review-graph/), [caveman](https://github.com/JuliusBrussee/caveman), or any third-party skill repositories listed in `skills/registry.yaml`.
- Vulnerabilities in dependencies (npm, brew, apt packages) — report to those projects.
