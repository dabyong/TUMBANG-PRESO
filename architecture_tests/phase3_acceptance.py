"""Test-only Phase 3 scenarios. See the architecture package for adapter I/O."""

import argparse
import json
import subprocess
import sys


QUESTIONS = [
    {
        "questionId": f"q{number}",
        "answerOptionIds": [f"q{number}-{letter}" for letter in "dbaec"],
        "correctOptionId": f"q{number}-a",
        "hint": f"Fixture hint for question {number}",
    }
    for number in range(1, 6)
]


def start(session="s1", difficulty="normal"):
    return dict(op="start", sessionId=session, provinceId="batanes",
                difficulty=difficulty, questions=QUESTIONS)


def answer(question, letter, session="s1", command_id=None, **options):
    return dict(op="answer", commandId=command_id or f"{session}/q{question}/{letter}",
                questionId=f"q{question}", optionId=f"q{question}-{letter}", **options)


def correct(first=1, last=5, session="s1"):
    return [answer(question, "a", session) for question in range(first, last + 1)]


def capture(name):
    return dict(op="capture", name=name)


def restart(*, hold_feedback=False):
    return dict(op="restart", holdFeedback=True) if hold_feedback else dict(op="restart")


def successful(score, stars):
    return {"state": "Victory", "score": score, "stars": stars,
            "progress": {"unlockedProvinceIds": ["batanes", "cagayan"],
                         "completedProvinceIds": ["batanes"],
                         "records": {"batanes/normal": {"bestScore": score,
                                                        "bestStars": stars}}}}


def scenarios():
    for misses, award in enumerate((100, 75, 50, 25, 10)):
        stars = (3, 3, 2, 2, 1)[misses]
        ops = [start(), *[answer(1, letter) for letter in "bcde"[:misses]],
               *correct(), capture("done")]
        yield (f"score-{misses}-prior-misses", ops,
               {"done": {**successful(award + 400, stars), "misses": misses}})

    initial_progress = {"unlockedProvinceIds": ["batanes"],
                        "completedProvinceIds": [], "records": {}}
    failure = {"state": "Failure", "score": 110, "misses": 5, "stars": 0}
    def failing_attempt(session):
        return [answer(1, "a", session),
                *[answer(2, letter, session) for letter in "bcde"],
                answer(2, "a", session),
                answer(3, "b", session)]

    fail = failing_attempt("s1")
    yield ("failed-run-no-progress", [start(), *fail, answer(3, "a"), capture("failed")],
           {"failed": {**failure, "hintAvailable": False, "progress": initial_progress}})

    best = successful(500, 3)["progress"]
    best_with_hard = {**best, "records": {**best["records"],
                                          "batanes/hard": {"bestScore": 500, "bestStars": 3}}}
    yield (
        "replay-records-only-improve-on-success",
        [start(), answer(1, "b"), *correct(), capture("first"),
         start("s2"), *correct(session="s2"), capture("higher"),
         start("s3"), *[answer(1, letter, "s3") for letter in "bcde"],
         *correct(session="s3"), capture("lower"),
         start("s4", "hard"), *failing_attempt("s4"), capture("failed"),
         start("s5", "hard"), *correct(session="s5"), capture("hard")],
        {"first": successful(475, 3),
         "higher": successful(500, 3),
         "lower": {"state": "Victory", "score": 410, "stars": 1, "progress": best},
         "failed": {**failure, "progress": best},
         "hard": {"state": "Victory", "score": 500, "stars": 3, "progress": best_with_hard}},
    )

    recovered = {
        "state": "AwaitingAnswer", "provinceId": "batanes", "difficulty": "normal",
        "questionIds": [item["questionId"] for item in QUESTIONS],
        "optionOrderByQuestion": {item["questionId"]: item["answerOptionIds"] for item in QUESTIONS},
        "questionIndex": 1, "rejectedOptionIdsByQuestion": {"q2": ["q2-b"]},
        "incorrectAttemptsByQuestion": {"q2": 1}, "resolvedAnswerIds": {"q1": "q1-a"},
        "misses": 1, "score": 100,
    }
    yield ("deterministic-recovery-and-duplicate-miss",
           [start(), answer(1, "a"), answer(2, "b"), capture("before"), restart(),
            answer(2, "b"), answer(2, "b", command_id="duplicate-tap"), capture("after"),
            *correct(2), capture("done")],
           {"before": recovered, "after": recovered, "done": successful(475, 3)})

    yield ("right-answer-replay-after-committed-write",
           [start(), answer(1, "a", interruptAt="afterSlotWriteBeforeFeedback"),
            restart(hold_feedback=True), answer(1, "a"), answer(1, "a", command_id="stale-tap"),
            capture("pending"), {"op": "acknowledgeFeedback"}, capture("after"),
            *correct(2), capture("done")],
           {"pending": {"state": "Feedback", "feedbackOutcome": "correct",
                        "feedbackRequiresAcknowledgement": True, "questionIndex": 0,
                        "score": 100, "misses": 0, "resolvedAnswerIds": {"q1": "q1-a"}},
            "after": {"state": "AwaitingAnswer", "score": 100, "misses": 0, "questionIndex": 1,
                      "resolvedAnswerIds": {"q1": "q1-a"}}, "done": successful(500, 3)})

    yield ("terminal-commit-idempotent",
           [start(), *correct(last=4), answer(5, "a", interruptAt="afterTerminalCommitBeforeResults"),
            restart(), answer(5, "a"), capture("done")],
           {"done": successful(500, 3)})

    yield ("interrupted-write-retains-prior-generation",
           [start(), answer(1, "a"), answer(2, "b", interruptAt="midTempWrite"), restart(),
            capture("recovered"), answer(2, "b"), capture("retried")],
           {"recovered": {"questionIndex": 1, "score": 100, "misses": 0},
            "retried": {"questionIndex": 1, "score": 100, "misses": 1}})

    yield ("corrupt-newest-slot-falls-back",
           [start(), answer(1, "a"), answer(2, "b"), {"op": "corruptNewestSlot"},
            restart(), capture("recovered")],
           {"recovered": {"questionIndex": 1, "score": 100, "misses": 0}})

    yield ("both-slots-unreadable",
           [start(), answer(1, "a"), {"op": "corruptBothSlots"}, restart(), capture("recovery")],
           {"recovery": {"state": "RecoveryRequired", "filesPreserved": True}})

    for difficulty, threshold in (("easy", 0), ("normal", 1), ("hard", 2)):
        attempts = {"state": "AwaitingAnswer", "difficulty": difficulty, "questionIndex": 0}
        yield (
            f"hints-{difficulty}",
            [start(difficulty=difficulty), capture("before"),
             answer(1, "b"), capture("firstMiss"), restart(), capture("restoredFirstMiss"),
             answer(1, "b", command_id="rejected-option-retry"), capture("duplicateMiss"),
             answer(1, "c"), capture("secondMiss"), restart(), capture("restoredSecondMiss"),
             answer(1, "a"), capture("nextQuestion")],
            {"before": {**attempts, "hintAvailable": threshold == 0, "misses": 0},
             "firstMiss": {**attempts, "hintAvailable": threshold <= 1, "misses": 1},
             "restoredFirstMiss": {**attempts, "hintAvailable": threshold <= 1, "misses": 1},
             "duplicateMiss": {**attempts, "hintAvailable": threshold <= 1, "misses": 1},
             "secondMiss": {**attempts, "hintAvailable": True, "misses": 2},
             "restoredSecondMiss": {**attempts, "hintAvailable": True, "misses": 2},
             "nextQuestion": {**attempts, "questionIndex": 1,
                              "hintAvailable": threshold == 0, "misses": 2, "score": 50}},
        )


def record_merge_scenarios():
    """Synthetic wins isolate the record merge from the difficulty/scoring rules."""
    def victory(score, stars):
        return {"op": "recordSuccessfulRun", "provinceId": "batanes",
                "difficulty": "normal", "score": score, "stars": stars}

    def snapshot(score, stars):
        return {"records": {"batanes/normal": {"bestScore": score, "bestStars": stars}}}

    yield (
        "score-improves-independently-of-stars",
        [victory(425, 3), capture("first"), victory(475, 2), capture("second")],
        {"first": snapshot(425, 3), "second": snapshot(475, 3)},
    )
    yield (
        "stars-improve-independently-of-score",
        [victory(475, 2), capture("first"), victory(425, 3), capture("second"),
         victory(410, 1), capture("lowerReplay")],
        {"first": snapshot(475, 2), "second": snapshot(475, 3),
         "lowerReplay": snapshot(475, 3)},
    )


def differences(expected, actual, path="checkpoints"):
    exact_map = path.endswith((".progress", ".records"))
    if isinstance(expected, dict) and isinstance(actual, dict) and not exact_map:
        for key, value in expected.items():
            if key not in actual:
                yield f"{path}.{key}: missing"
            else:
                yield from differences(value, actual[key], f"{path}.{key}")
    elif type(expected) is not type(actual) or expected != actual:
        yield f"{path}: expected {expected!r}, got {actual!r}"


def validate_plan(cases):
    assert len(cases) == len({name for name, _, _ in cases}), "Duplicate scenario names"
    for name, operations, expected in cases:
        captures = {op["name"] for op in operations if op["op"] == "capture"}
        assert captures == set(expected), f"{name}: unmatched checkpoints"
        json.loads(json.dumps({"protocolVersion": 1, "scenario": name, "operations": operations}))
        assert not list(differences(expected, expected))
    assert list(differences({"score": 100}, {"score": 75}))
    assert list(differences({"score": 100}, {}))
    assert list(differences({"progress": {"records": {}}},
                            {"progress": {"records": {"batanes/normal": {"bestScore": 100}}}}))


def unique_json_object(pairs):
    entry = {}
    for key, value in pairs:
        if key in entry:
            raise ValueError(f"Duplicate JSON key: {key}")
        entry[key] = value
    return entry


def run_adapter(cases, command):
    failed = 0
    for name, operations, expected in cases:
        payload = {"protocolVersion": 1, "scenario": name, "operations": operations}
        try:
            result = subprocess.run(command, input=json.dumps(payload), text=True,
                                    encoding="utf-8", capture_output=True,
                                    check=True, timeout=60)
            response = json.loads(result.stdout, object_pairs_hook=unique_json_object)
            if not isinstance(response, dict):
                raise ValueError("Expected a JSON object with protocolVersion 1")
            version = response.get("protocolVersion")
            if type(version) is not int or version != 1:
                raise ValueError("Expected a JSON object with protocolVersion 1")
            actual = response.get("checkpoints")
            if not isinstance(actual, dict) or set(actual) != set(expected):
                raise ValueError(f"Expected exactly these checkpoint names: {', '.join(expected)}")
            if any(not isinstance(snapshot, dict) for snapshot in actual.values()):
                raise ValueError("Each checkpoint must be a JSON object")
            errors = list(differences(expected, actual))
        except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
            detail = getattr(exc, "stderr", None)
            errors = [f"{exc} {detail or ''}".strip()]
        if errors:
            failed += 1
        print(f"{'FAIL' if errors else 'PASS'} {name}")
        for error in errors:
            print(f"  {error}")
    return int(failed > 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-plan", action="store_true")
    mode.add_argument("--adapter", nargs=argparse.REMAINDER, metavar="COMMAND")
    mode.add_argument("--domain-adapter", nargs=argparse.REMAINDER, metavar="COMMAND")
    args = parser.parse_args()
    cases = list(scenarios())
    domain_cases = list(record_merge_scenarios())
    validate_plan(cases)
    validate_plan(domain_cases)
    if args.check_plan:
        print(f"Validated {len(cases)} acceptance and {len(domain_cases)} domain test "
              "specifications. No Godot adapter was run.")
        return 0
    if args.domain_adapter is not None:
        if not args.domain_adapter:
            parser.error("--domain-adapter requires a command")
        return run_adapter(domain_cases, args.domain_adapter)
    if not args.adapter:
        parser.error("--adapter requires a command")
    return run_adapter(cases, args.adapter)


if __name__ == "__main__":
    sys.exit(main())

