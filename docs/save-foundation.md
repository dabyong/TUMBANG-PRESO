# Local persistence contract

The repository has one serialized writer. A caller submits a complete JSON-compatible snapshot. The repository writes a numbered staging file, flushes it, verifies it, and renames it in the same directory to publish that generation. Published generations are immutable. The envelope contains the exact serialized body and its SHA-256 digest. Save-envelope schema 2 defines the generation and payload. A matching checksum verifies the stored body. Gameplay validation independently checks the payload and compatibility.

| Load status | Meaning |
| --- | --- |
| First launch | The directory is readable and contains no recognized save artifacts. |
| Ready | The newest verified committed snapshot is available. |
| Recovered | A verified committed snapshot is available alongside damaged data or a newer staged write. |
| Recovery required | Existing artifacts cannot provide a normal load, or an unsupported schema blocks writes. |
| Unreadable | The save directory could not be opened or listed. |

`load_latest()` exposes the newest envelope-verified committed snapshot, envelope-verified committed generation IDs, file-level diagnostics, the newest eligible staged generation, and whether the filesystem or schema blocks writes. Ordinary writes pause while the staged recovery choice is pending. Explicit deferral renames the eligible file to `tp-save-N.deferred` in the same directory, preserving its bytes and ending eligibility for stages at or below that generation. If only damaged or deferred data exists, keep the files for export or repair. Unchecksummed pre-hardening saves are retained for manual review.

After verifying a published generation, the repository keeps the three newest committed generations that pass envelope verification and the supplied payload validator. Gameplay supplies its content-aware validator for normal writes and both recovery publication paths. Only eligible generations count toward the limit. Cleanup verifies each candidate before deletion. An individual cleanup failure leaves extra history and the next verified publication retries cleanup. Staged, deferred, damaged, incompatible, and unsupported-schema artifacts are retained for diagnosis or recovery.

The next generation uses the highest recognized filename across staged, deferred, and committed artifacts, including damaged files. Pruning lower generations leaves that high-water mark in place. The repository rejects writes at the maximum JSON-safe generation, 9,007,199,254,740,991. A staged file is eligible only when its number exceeds every recognized committed and deferred filename, including damaged ones. Explicit committed recovery copies the selected older payload into a newly numbered generation, preserving the rejected newer snapshot.

Gameplay session and progression share one payload. The gameplay layer validates the payload before publishing or promoting a stage and validates the newest checksum-verified payload on restore. Content mismatch or an inconsistent payload requires explicit recovery. The repository contract assumes a single serialized writer. The automated checks simulate interruption and corruption. Mobile power-loss durability remains unverified. [Gameplay session and Phase 3 adapter](gameplay-domain.md)
