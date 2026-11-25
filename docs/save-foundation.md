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

Generation retention is append-only in this milestone. Before high-frequency session checkpoints ship, add a bounded retention policy after validating successful publication, and test mobile behavior during abrupt termination. The current checks simulate interrupted publication and truncated data rather than device-level power failure.

For Milestone 2, commit session and progression as one payload. The session contract must carry province and difficulty, ordered question IDs, per-question option order, current index, rejected options, incorrect attempts per question, misses, score, gameplay state, resolved answers, and stable processed submission IDs. Store content version information to prevent recovery against a changed catalog. Commit accepted-answer state before acknowledging the submission. Use the persisted IDs to reject duplicate submissions without replaying the transition.
