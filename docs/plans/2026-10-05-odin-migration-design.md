# Odin migration: graph-first design

## Scope and graph semantics

This map follows sourced Firstmate libraries reachable from `bin/fm-brief.sh`, including conditional lazy sources.
The graph distinguishes source-time library edges from runtime script calls and external tools.

```text
bin/fm-brief.sh
├── source bin/fm-marker-lib.sh
│   └── source bin/fm-operational-input.sh
├── source bin/fm-classify-lib.sh
│   ├── source bin/fm-timeout-lib.sh
│   └── lazy source bin/fm-parent-channel-lib.sh
│       ├── source bin/fm-secondmate-parent-lib.sh
│       └── source bin/fm-classify-lib.sh  [already loaded; cycle closes here]
└── source bin/fm-dod-lib.sh
    ├── source bin/fm-pr-lib.sh
    ├── source bin/fm-classify-lib.sh  [already loaded]
    ├── source bin/fm-nm-run-lib.sh
    └── source bin/fm-brief-heading-lib.sh
```

`fm-marker-lib.sh` is a 12-line compatibility shim, so its behavior lives in the 435-line `fm-operational-input.sh` leaf.
`fm-classify-lib.sh` loads `fm-parent-channel-lib.sh` only when a parent-channel helper is called, and that library re-sources the classifier to avoid a top-level cycle.
`fm-dod-lib.sh` also sources `fm-pr-lib.sh`, `fm-nm-run-lib.sh`, and `fm-brief-heading-lib.sh` at load time, even though only selected renderers run while scaffolding a brief.
The useful source-graph leaves are `fm-operational-input.sh`, `fm-timeout-lib.sh`, `fm-secondmate-parent-lib.sh`, `fm-pr-lib.sh`, `fm-nm-run-lib.sh`, and `fm-brief-heading-lib.sh`.
The 70-line `fm-secondmate-parent-lib.sh` is the smallest leaf with standalone parsing behavior; the smaller marker library is only a compatibility forwarding shim.

## Runtime edges and tool boundary

The scout branch of `fm-brief.sh` executes `fm-bootstrap.sh lavish-compatible`; ship and secondmate generation do not take that branch.
The absorb-classification functions in `fm-classify-lib.sh` can execute `fm-crew-state.sh`, but the brief generator does not call those functions.
`fm-dod-lib.sh` can run a bounded `bash -c` that sources the already-listed `fm-pr-lib.sh` while checking a Gerrit change.
Other script names in brief prose, comments, and emitted shell snippets are instructions or descriptions rather than execution edges from this generator.

Shell built-ins used across the root and libraries include `.`/`source`, `case`, `read`, `printf`, `test`/`[`, `[[`, shell parameter expansion, functions, loops, redirections, and command substitution.
External tools used by the root generator include `dirname`, `awk`, `git`, `cat`, `mkdir`, `grep`, `tr`, and `sed`, with the `fm-bootstrap.sh` call limited to the scout branch.
The operational-input leaf additionally uses `date`, `find`, `stat`, `od`, `xargs`, `mktemp`, `mv`, and `rm` for record-backed commands.
The classifier and timeout libraries additionally use `uname`, `tail`, `head`, `sleep`, `kill`, `perl`, `timeout`, and `gtimeout` in their applicable paths.
The parent-channel libraries additionally use `wc`, `tr`, `cat`, `cut`, `mkdir`, and `dirname`.
The DOD dependency group additionally uses `git`, `gh`, `jq`, `stat`, `shasum` or `sha256sum`, `awk`, `sed`, `grep`, `tail`, `head`, `cut`, and the `no-mistakes` CLI in applicable checks.
`fm-brief-heading-lib.sh` delegates line scanning to external `awk` and has no internal Firstmate-script dependency.

## Approved graph-first plan

The first increment ports only `fm-secondmate-parent-lib.sh` behavior to Odin under `src/odin/` because it is the smallest useful leaf in the transitive helper graph.
Its parity test compares the existing sourced shell function's validity and parsed fields with the Odin executable's public output for the same records.
The shell libraries and callers remain unchanged, and test binaries are built in a temporary directory rather than under `bin/`.

Later increments should port additional independent leaves with executable-level parity tests, then port dependent libraries only after their graph dependencies are represented in Odin.
The larger operational-input leaf remains a separate step because its record creation, validation, retention, and filesystem behavior need their own bounded parity scope.
Caller migration begins only after the Odin replacements cover the behavior each caller actually uses; `src/odin/fm-brief.odin` remains unchanged in this increment.
