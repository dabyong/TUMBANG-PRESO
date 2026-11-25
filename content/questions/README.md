# Question content

Question records are intentionally empty in Milestone 1. Gameplay content belongs to Milestone 2.

The catalog declares `mode: "foundation"` for empty fixtures or `mode: "playable"` for approved content. Empty pools are unavailable. A populated pool requires at least five unique question IDs with the same province and difficulty. Playable catalogs require a populated starting-province pool.

Approved records use `verificationStatus: "approved"`, one of `easy`, `normal`, or `hard`, and a `source` object with non-blank `title` and `reference` fields. A reference can be a URL or a bibliographic locator. Each of the five options supplies an `optionId` and visible `text`. Labels must be distinct after case and common whitespace normalization. Reviewers still verify facts and sources separately.

Campaign route prerequisites use `unlock.allCompletedProvinceIds`. The validator treats routes as directed, with all listed completions required before a route becomes available from its source.
