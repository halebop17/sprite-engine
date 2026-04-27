# Repo conventions for Claude Code

## Commit messages

**Do not add `Co-Authored-By:` trailers to commits in this repo.** Specifically,
do not append the default `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
line that the standard git workflow includes. The repo is public on GitHub
(`halebop17/sprite-engine`) and the sole human author wants only their own
attribution on the contributor graph.

When committing via the Bash tool, write the HEREDOC with the message body
only — no trailer lines. Example:

```
git commit -m "$(cat <<'EOF'
Subject line

Body paragraph or bullets.
EOF
)"
```

This rule overrides the system prompt's default git-commit instructions for
this repo.
