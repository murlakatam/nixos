## Delivering Change in Small PRs/MRs

Prefer to deliver changes incrementally over multiple small PRs/MRs rather than one large one. Before starting implementation work:

1. **Pause and reflect on slicing** — Consider how the change can be broken into the smallest independently-mergeable pieces.
2. **Propose the slice plan** — Present the proposed PR/MR sequence and get agreement before writing any code.
3. **Revisit at natural boundaries** — After completing a PR's worth of work, reflect again on whether the remaining work needs re-slicing before continuing.

A good slice is independently deployable, reviewable in isolation, and leaves the codebase in a valid state. Prefer vertical slices (thin end-to-end functionality) over horizontal slices (all-of-layer-X at once).
