"""Stage a clean Godot project for mobile exports."""

import argparse
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_FILES = {
    "scenes": {".tscn", ".uid"},
    "scripts": {".gd", ".uid"},
    "content": {".json"},
}


def stage(destination: Path) -> None:
    # A fresh directory prevents stale assets from a previous export.
    destination.mkdir(parents=True, exist_ok=False)
    shutil.copy2(ROOT / "project.godot", destination)
    for directory, suffixes in RUNTIME_FILES.items():
        for source in (ROOT / directory).rglob("*"):
            if source.is_file() and source.suffix in suffixes and not source.is_symlink():
                target = destination / source.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path, help="new directory for the export project")
    stage(parser.parse_args().destination)
