#!/usr/bin/env python3
"""
dependency_graph.py - Automatic Dev Setup

Purpose:
    Analyse the repository for Automatic Dev Setup environment-variable
    dependencies and emit a machine-readable graph describing how files rely on
    each ADS_* variable. The script scans shell scripts, Python helpers,
    Markdown documentation, and configuration files to ensure every consumer of
    a variable is visible. Output can be generated in Graphviz DOT or JSON
    format for further visualisation.

Usage:
    python tools/dependency_graph.py --format dot > ads-dependencies.dot
    python tools/dependency_graph.py --format json --filter TEMPLATE

Notes:
    * No files are modified; the tool is read-only.
    * Variables defined in automatic-dev-config.env are treated as authoritative
      definitions. Files that reference ADS_* without being defined are treated
      as consumers.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Set, Tuple

RE_VARIABLE = re.compile(r"\b(ADS_[A-Z0-9_]+)\b")
RE_EXPORT = re.compile(r"^\s*export\s+(ADS_[A-Z0-9_]+)\b")
DEFAULT_EXTENSIONS = {
    ".sh",
    ".env",
    ".py",
    ".md",
    ".txt",
    ".yml",
    ".yaml",
}


@dataclass
class Edge:
    source: str
    target: str
    relation: str  # "defines" or "consumes"


def iter_repository_files(root: Path, extensions: Set[str]) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix in extensions:
            yield path


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def discover_definitions(config_path: Path) -> Dict[str, str]:
    definitions: Dict[str, str] = {}
    if not config_path.exists():
        return definitions
    for line in read_text(config_path).splitlines():
        match = RE_EXPORT.match(line)
        if match:
            definitions[match.group(1)] = str(config_path.relative_to(Path.cwd()))
    return definitions


def build_edges(
    root: Path,
    extensions: Set[str],
    definitions: Dict[str, str],
    ignore_paths: Set[str],
) -> Tuple[List[Edge], Dict[str, Set[str]]]:
    edges: List[Edge] = []
    variables_to_files: Dict[str, Set[str]] = defaultdict(set)

    for path in iter_repository_files(root, extensions):
        rel_path = str(path.relative_to(root))
        if any(rel_path.startswith(prefix) for prefix in ignore_paths):
            continue
        text = read_text(path)
        matches = set(RE_VARIABLE.findall(text))
        if not matches:
            continue
        for var in matches:
            variables_to_files[var].add(rel_path)
            if var in definitions and rel_path == definitions[var]:
                # Definition already represented by file -> var edge later.
                continue
            edges.append(Edge(source=var, target=rel_path, relation="consumes"))

    for var, file_path in definitions.items():
        edges.append(Edge(source=file_path, target=var, relation="defines"))

    return edges, variables_to_files


def filter_edges(edges: Iterable[Edge], keyword: str | None) -> List[Edge]:
    if not keyword:
        return list(edges)
    key = keyword.lower()
    return [
        edge
        for edge in edges
        if key in edge.source.lower() or key in edge.target.lower()
    ]


def to_dot(edges: Iterable[Edge]) -> str:
    lines = [
        "digraph ADS_DependencyGraph {",
        '  rankdir=LR;',
        '  node [shape=box, style="rounded,filled", fillcolor="#f2f2f2"];',
    ]
    for edge in edges:
        attributes = ' [label="{label}"]'.format(label=edge.relation)
        source = edge.source.replace('"', r"\"")
        target = edge.target.replace('"', r"\"")
        lines.append(f'  "{source}" -> "{target}"{attributes};')
    lines.append("}")
    return "\n".join(lines)


def to_json(edges: Iterable[Edge]) -> str:
    payload = [
        {"source": edge.source, "target": edge.target, "relation": edge.relation}
        for edge in edges
    ]
    return json.dumps(payload, indent=2)


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Visualise ADS_* environment variable dependencies."
    )
    parser.add_argument(
        "--format",
        choices={"dot", "json"},
        default="dot",
        help="Output format (Graphviz DOT or JSON).",
    )
    parser.add_argument(
        "--filter",
        help="Filter edges by substring (applied to both node names).",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Repository root (defaults to current working directory).",
    )
    parser.add_argument(
        "--ignore",
        default="special_files/24102025_VM_logs",
        help="Comma-separated path prefixes to ignore.",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    if not root.exists():
        print(f"[ERROR] Repository root not found: {root}", file=sys.stderr)
        return 1

    config_path = root / "automatic-dev-config.env"
    definitions = discover_definitions(config_path)
    ignore_prefixes = {prefix.strip() for prefix in args.ignore.split(",") if prefix}

    edges, _ = build_edges(
        root=root,
        extensions=DEFAULT_EXTENSIONS,
        definitions=definitions,
        ignore_paths=ignore_prefixes,
    )
    edges = filter_edges(edges, args.filter)

    if args.format == "dot":
        output = to_dot(edges)
    else:
        output = to_json(edges)

    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
