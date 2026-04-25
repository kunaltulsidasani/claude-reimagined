#!/usr/bin/env bash
# PreCompact Hook — project-aware compact instructions
# stdout → custom instructions injected into compaction summarizer
# exit 0 = proceed | exit 2 = block compaction

# ─── Tech Stack Detection ──────────────────────────────────────────────────────

PROJECT_TYPE=""
TEST_CMD=""
BUILD_CMD=""
SCHEMA_FILE=""
KEY_DIRS=""

# JavaScript / TypeScript
if [ -f "package.json" ]; then
    PROJECT_TYPE="javascript"
    [ -f "tsconfig.json" ] && PROJECT_TYPE="typescript"

    if grep -qE '"next"' package.json 2>/dev/null; then
        PROJECT_TYPE="$PROJECT_TYPE/nextjs"
    elif grep -qE '"@nestjs/core"' package.json 2>/dev/null; then
        PROJECT_TYPE="$PROJECT_TYPE/nestjs"
    elif grep -qE '"react"' package.json 2>/dev/null; then
        PROJECT_TYPE="$PROJECT_TYPE/react"
    elif grep -qE '"express|fastify|koa|hapi"' package.json 2>/dev/null; then
        PROJECT_TYPE="$PROJECT_TYPE/node-backend"
    fi

    if grep -qE '"vitest"' package.json 2>/dev/null; then
        TEST_CMD="npx vitest"
    elif grep -qE '"jest"' package.json 2>/dev/null; then
        TEST_CMD="npm test"
    fi
    BUILD_CMD="npm run build"
fi

# Go
if [ -f "go.mod" ]; then
    MODULE=$(grep '^module' go.mod 2>/dev/null | awk '{print $2}')
    PROJECT_TYPE="go${MODULE:+ (module: $MODULE)}"
    TEST_CMD="go test ./..."
    BUILD_CMD="go build ./..."
fi

# Python
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    PROJECT_TYPE="python"
    if grep -q "fastapi" pyproject.toml 2>/dev/null; then
        PROJECT_TYPE="python/fastapi"
    elif grep -q "django" pyproject.toml 2>/dev/null; then
        PROJECT_TYPE="python/django"
    elif grep -q "flask" pyproject.toml 2>/dev/null; then
        PROJECT_TYPE="python/flask"
    fi
    TEST_CMD="pytest"
fi

# Rust
if [ -f "Cargo.toml" ]; then
    PROJECT_TYPE="rust"
    TEST_CMD="cargo test"
    BUILD_CMD="cargo build"
fi

# Flutter / Dart
if [ -f "pubspec.yaml" ]; then
    PROJECT_TYPE="flutter/dart"
    TEST_CMD="flutter test"
    BUILD_CMD="flutter build"
fi

# Java / Kotlin
if [ -f "pom.xml" ]; then
    PROJECT_TYPE="java/maven"
    TEST_CMD="mvn test"
    BUILD_CMD="mvn package"
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    PROJECT_TYPE="kotlin/gradle"
    TEST_CMD="./gradlew test"
    BUILD_CMD="./gradlew build"
fi

# Ruby
if [ -f "Gemfile" ]; then
    PROJECT_TYPE="ruby"
    grep -q "rails" Gemfile 2>/dev/null && PROJECT_TYPE="ruby/rails"
    TEST_CMD="bundle exec rspec"
fi

# Swift
if [ -f "Package.swift" ]; then
    PROJECT_TYPE="swift"
    TEST_CMD="swift test"
    BUILD_CMD="swift build"
fi

# C# / .NET
if ls ./*.csproj 2>/dev/null | grep -q .; then
    PROJECT_TYPE="csharp/dotnet"
    TEST_CMD="dotnet test"
    BUILD_CMD="dotnet build"
fi

# ─── Schema Detection ──────────────────────────────────────────────────────────

for f in \
    prisma/schema.prisma \
    drizzle/schema.ts \
    src/db/schema.ts \
    supabase/migrations \
    schema.graphql \
    src/schema.graphql \
    db/schema.go \
    internal/models \
    pkg/models \
    src/models \
    models.py; do
    if [ -e "$f" ]; then
        SCHEMA_FILE="$f"
        break
    fi
done

# ─── API Directory Detection ───────────────────────────────────────────────────

for d in \
    src/api src/routes src/app/api \
    api routes server/routes \
    internal/handler internal/api \
    pkg/handler cmd/api \
    app/controllers app/api; do
    [ -d "$d" ] && KEY_DIRS="$KEY_DIRS $d"
done

# ─── Git State ─────────────────────────────────────────────────────────────────

GIT_BRANCH=""
GIT_CHANGES=""
GIT_STAGED=""
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
    GIT_BRANCH=$(git branch --show-current 2>/dev/null)
    GIT_CHANGES=$(git diff --name-only 2>/dev/null | head -15)
    GIT_STAGED=$(git diff --cached --name-only 2>/dev/null | head -10)
fi

# ─── CLAUDE.md Key Decisions ───────────────────────────────────────────────────

KEY_DECISIONS=""
for md in CLAUDE.md .claude/CLAUDE.md; do
    if [ -f "$md" ]; then
        KEY_DECISIONS=$(awk '/^## Key Decisions/{f=1;next} /^## /{f=0} f' "$md" | head -20)
        break
    fi
done

# ─── Output Instructions ───────────────────────────────────────────────────────

echo "## Compact Instructions — Project-Aware Preservation"
echo ""
[ -n "$PROJECT_TYPE" ] && echo "Stack: $PROJECT_TYPE" && echo ""

cat <<'INSTRUCTIONS'
### MUST PRESERVE (priority order)

**1. Active Task & Next Steps**
What was being done at compact time. If mid-execution:
- Which step in the sequence
- Which tool was running and what it was doing
- What the NEXT action was going to be
- All pending steps not yet completed

**2. Goal**
User's original request in 1-2 sentences. Include any scope changes mid-session.

**3. Key Files**
Every file read, edited, or referenced. Format: `path:line — why it matters`.
Include files that were ABOUT to be edited next.

**4. Errors — verbatim**
EXACT error text, not paraphrases. For each error include:
- Full error message
- File and line number
- Fix applied and whether it was verified (tests pass/fail state)

**5. Decisions & Findings**
Non-obvious choices with the WHY. If we chose X over Y, keep the reason.
Constraints discovered, invariants found, edge cases identified.

**6. Pending / Blocked**
Anything queued or waiting. If a tool was in-flight, note what it was doing
and what result was expected.

**7. Env & Constraints**
Env vars, config values, flags, credentials shape, infra constraints —
anything discovered during session that affects future steps.
INSTRUCTIONS

# Project-specific additions
if [ -n "$KEY_DECISIONS" ]; then
    echo ""
    echo "**Settled Project Decisions (reference by name, don't re-derive):**"
    echo "$KEY_DECISIONS"
fi

if [ -n "$SCHEMA_FILE" ]; then
    echo ""
    echo "**Schema:** \`$SCHEMA_FILE\`"
    echo "Preserve ALL schema discussion: column names, relationships, migration decisions, data model reasoning."
fi

if [ -n "$KEY_DIRS" ]; then
    echo ""
    echo "**API directories:**$KEY_DIRS"
    echo "Preserve exact endpoint paths, request/response shapes, status codes, validation rules."
fi

if [ -n "$TEST_CMD" ]; then
    echo ""
    echo "**Test command:** \`$TEST_CMD\`"
    echo "Preserve last known test state: what passes, what fails, what was flaky."
fi

if [ -n "$BUILD_CMD" ]; then
    echo "**Build command:** \`$BUILD_CMD\`"
fi

# Git state
if [ -n "$GIT_BRANCH" ]; then
    echo ""
    echo "**Branch:** $GIT_BRANCH"
fi

if [ -n "$GIT_CHANGES" ]; then
    echo ""
    echo "**Uncommitted changes:**"
    echo "$GIT_CHANGES"
fi

if [ -n "$GIT_STAGED" ]; then
    echo ""
    echo "**Staged for commit:**"
    echo "$GIT_STAGED"
fi

cat <<'INSTRUCTIONS'

### DO NOT PRESERVE
- Exploration / approaches that led nowhere (dead ends)
- Full file contents that can be re-read from disk
- Tool result formatting — just the key findings
- Repeated test-fix-test cycles → compress to: "Fixed X by doing Y, tests now pass"
- Restatements, meta-commentary, pleasantries

### COMPRESSION RULE
Every line in the summary must be load-bearing for resuming work cold.
If removing a line wouldn't confuse someone picking up mid-task, cut it.
INSTRUCTIONS

exit 0
