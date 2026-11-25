# Local persistence contract

The repository has one serialized writer. A caller submits a complete JSON-compatible snapshot. The repository writes a numbered staging file, flushes it, verifies it, and renames it in the same directory to publish that generation. Published generations are immutable. The envelope contains the exact serialized body and its SHA-256 digest. The body contains schema version 2, generation and a dictionary payload. The digest detects corruption and is not an authentication mechanism.

| Load status | Meaning |
| --- | --- |
| First launch | The directory is readable and contains no recognized save artifacts. |
| Ready | The newest verified committed snapshot is available. |
| Recovered | A verified committed snapshot is available alongside damaged data or a newer staged write. |
| Recovery required | Existing artifacts cannot provide a normal load, or an unsupported schema blocks writes. |
| Unreadable | The save directory could not be opened or listed. |

`load_latest()` exposes the verified snapshot, file-level diagnostics, the newest eligible staged generation, and whether the filesystem or schema blocks writes. `recover_staged(generation)` explicitly verifies and promotes the newest eligible staged generation. Ordinary writes pause while that recovery choice is pending. If only damaged data exists, keep the files for export or repair. The foundation has no reset operation. Unchecksummed pre-hardening saves are flagged for manual review and retained.

After verifying a published generation, the repository keeps the three newest checksum-verified committed generations. That gives the current snapshot two predecessors and covers the answer and acknowledgement writes for one complete feedback cycle. Cleanup re-verifies each candidate before deletion. An individual cleanup failure leaves extra history and the next verified publication retries cleanup. Staged, damaged, and unsupported-schema artifacts are retained for diagnosis or recovery.

The next generation uses the highest recognized filename across staged and committed artifacts, including damaged files. Pruning lower generations leaves that high-water mark in place. The repository rejects writes at the maximum JSON-safe generation, 9,007,199,254,740,991. A staged file is eligible only when its number exceeds every recognized committed filename, including a damaged one. This prevents an older staged write from replacing a fallback after corruption.

Gameplay session and progression share one payload. The gameplay layer validates the payload before publishing or promoting a stage and validates the newest checksum-verified payload on restore. Content mismatch or an inconsistent payload requires explicit recovery. The repository contract assumes a single serialized writer. The automated checks simulate interruption and corruption. Mobile power-loss durability remains unverified. [Gameplay session and Phase 3 adapter](gameplay-domain.md)
