# Question content

Batanes ships with 15 sourced English questions per difficulty in catalog version `batanes-en-1`. The [verification report](../../docs/batanes-content-verification.md) records the evidence for each approved question.

The catalog declares `mode: "foundation"` for empty fixtures or `mode: "playable"` for approved content. Empty pools are unavailable. A populated pool requires at least five unique question IDs with the same province and difficulty. The production boot check requires all three difficulties in the starting province. Synthetic tests keep their foundation catalog and campaign fixtures under `tests/fixtures/`.

Approved records use `verificationStatus: "approved"`, one of `easy`, `normal`, or `hard`, and a `source` object with non-blank `title` and `reference` fields. A reference can be a URL or a bibliographic locator. Each of the five options supplies an `optionId` and visible `text`. Labels must be distinct after case and common whitespace normalization. Reviewers still verify facts and sources separately.

Campaign routes declare `travelMode` as `land` or `sea`. Routes are directed, and `unlock.allCompletedProvinceIds` lists the known, unique province completions required before a route becomes available from its source. An empty list opens the route as soon as its source is accessible.
