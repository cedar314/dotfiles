#!/usr/bin/env python3
"""Create local editable defaults exclusively; never replace existing state."""
from pathlib import Path
import sys
from files import safe_parents

source, destination = map(Path, sys.argv[1:])
repo = Path(__file__).resolve().parents[1]
if destination == repo or repo in destination.absolute().parents:
    raise ValueError('local editable state must be outside the repository')
safe_parents(destination)
destination.parent.mkdir(parents=True, exist_ok=True)
with destination.open('x') as stream:
    stream.write(source.read_text())
