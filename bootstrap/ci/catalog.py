"""Layer 3 — the task catalog: the only place CI workload is defined.

A task kind declares which packages instantiate it (``applies``), its
declarative job setup needs (``setup``), and the fully resolved lint and test
shell commands for one package instance (``commands``), with codegen implied
by that package's dependency closure per the codegen step graph.

A task instance is a task kind bound to one package, identified as
``<kind>:<package>`` (e.g. ``dart:efa_fit``). Standalone kinds cover workload
that is not attributable to a single package; they are selected by their own
blast-radius trigger patterns or by escalation rather than by package
matching.

Small packages (``Package.size``) do not instantiate alone: all selected
small packages of one kind run together in a single batched instance
(``<kind>:small``) that shares its runner setup across members. Large
packages always get a dedicated instance.

Task names are unstable identifiers: they name work, and branch protection
must never enumerate them.
"""

from __future__ import annotations

import json

from dataclasses import dataclass
from typing import Protocol

from bootstrap.ci.codegen import steps_for_packages
from bootstrap.ci.registry import PACKAGES
from bootstrap.ci.registry import Package
from bootstrap.constant import PROJECT_ROOT


@dataclass(frozen=True)
class Setup:
    """Declarative job needs for a task instance."""

    shell: str  # nix dev shell suffix (`.#<shell>`)
    uv_sync: bool = True  # uv sync (Python environment for `uv run` commands)
    pub_get: bool = False  # flutter pub get
    pnpm_install: bool = False  # pnpm install
    native_data: bool = False  # fetch ci-native-data.tar.gz
    dev_env: bool = False  # developer-config init + backend env


@dataclass(frozen=True)
class Commands:
    """Fully resolved shell commands for one task instance."""

    codegen: tuple[str, ...] = ()
    lint: tuple[str, ...] = ()
    test: tuple[str, ...] = ()


class TaskKind(Protocol):
    """A kind of CI work, instantiated per package."""

    id: str

    def applies(self, package: Package) -> bool: ...

    def setup(self, package: Package) -> Setup: ...

    def commands(self, package: Package) -> Commands: ...


def _codegen_commands(package: Package) -> tuple[str, ...]:
    """Render the codegen phase for a package from its dependency closure."""
    steps = steps_for_packages([package.id])
    if not steps:
        return ()
    return (f"uv run x.py ci codegen --steps {','.join(steps)}",)


def _has_pnpm_script(package: Package, script: str) -> bool:
    manifest = PROJECT_ROOT / package.path / "package.json"
    if not manifest.is_file():
        return False
    scripts = json.loads(manifest.read_text(encoding="utf-8")).get("scripts") or {}
    return script in scripts


class DartTask:
    """Analyze and format-check a Dart package; run its Flutter tests."""

    id = "dart"

    def applies(self, package: Package) -> bool:
        return package.ecosystem == "dart" and not package.opaque

    def setup(self, package: Package) -> Setup:
        return Setup(shell="dart", pub_get=True, native_data=True, dev_env=True)

    def commands(self, package: Package) -> Commands:
        lint: list[str] = []
        if package.id == "eve_fit_assistant":
            # The bundled docs/manual are analyzed as part of the app.
            lint += ["uv run x.py build docs", "uv run x.py build manual"]
        lint += [
            f"dart run melos exec --scope={package.id} -- dart analyze",
            f"dart run melos exec --scope={package.id} -- dart format --set-exit-if-changed lib",
        ]
        test = []
        if package.tests:
            test.append(f"dart run melos exec --scope={package.id} -- flutter test")
        return Commands(codegen=_codegen_commands(package), lint=tuple(lint), test=tuple(test))


class DartWebTask:
    """Whole-app test run on the web platform in headless Chrome."""

    id = "dart-web"

    def applies(self, package: Package) -> bool:
        return package.id == "eve_fit_assistant"

    def setup(self, package: Package) -> Setup:
        return Setup(shell="dart", pub_get=True, native_data=True, dev_env=True)

    def commands(self, package: Package) -> Commands:
        return Commands(codegen=_codegen_commands(package), test=("uv run x.py test web",))


class TsTask:
    """Biome format/lint over a TypeScript package plus its check/test scripts."""

    id = "ts"

    def applies(self, package: Package) -> bool:
        return package.ecosystem == "ts" and not package.opaque

    def setup(self, package: Package) -> Setup:
        # Only the codegen phase invokes `uv`; pure lint/test packages skip
        # the Python environment entirely.
        return Setup(shell="js", pnpm_install=True, uv_sync=bool(_codegen_commands(package)))

    def commands(self, package: Package) -> Commands:
        # `biome check` verifies format + lint + assist; a separate
        # `biome format` invocation would exit 0 without verifying anything.
        lint = [f"pnpm biome check {package.path}/"]
        if _has_pnpm_script(package, "check"):
            lint.append(f"pnpm --filter {package.id} check")
        test = []
        if package.tests:
            test.append(f"pnpm --filter {package.id} test")
        return Commands(codegen=_codegen_commands(package), lint=tuple(lint), test=tuple(test))


class RustTask:
    """cargo fmt/clippy for a crate; cargo test when the crate has tests."""

    id = "rust"

    def applies(self, package: Package) -> bool:
        return package.ecosystem == "rust" and not package.opaque

    def setup(self, package: Package) -> Setup:
        # Native data and the generated eve-fit-os .env are required to build
        # the workspace (prost-build + build-time data reads).
        return Setup(shell="rust", native_data=True, dev_env=True)

    def commands(self, package: Package) -> Commands:
        lint = [
            f"cargo fmt --check --package {package.id}",
            f"cargo clippy --package {package.id}",
        ]
        test = []
        if package.tests:
            test.append(f"cargo test --package {package.id}")
        return Commands(codegen=_codegen_commands(package), lint=tuple(lint), test=tuple(test))


@dataclass(frozen=True)
class StandaloneTask:
    """CI workload not attributable to a single package.

    ``trigger`` is this kind's blast-radius entry: path globs whose change
    selects the kind (escalation also selects every standalone kind).
    """

    id: str
    trigger: tuple[str, ...]
    job_setup: Setup
    job_commands: Commands


TASK_KINDS: tuple[TaskKind, ...] = (DartTask(), DartWebTask(), TsTask(), RustTask())

STANDALONE_KINDS: tuple[StandaloneTask, ...] = (
    StandaloneTask(
        id="python",
        trigger=("bootstrap/**", "x.py", "pyproject.toml", "uv.lock", "data/**"),
        job_setup=Setup(shell="python"),
        job_commands=Commands(
            codegen=("uv run x.py ci codegen --steps protobuf",),
            lint=("uv run ruff check .", "uv run ruff format --check ."),
            test=("uv run pytest bootstrap/tests/",),
        ),
    ),
    StandaloneTask(
        id="workflows",
        trigger=(".github/workflows/**", ".github/actions/**"),
        job_setup=Setup(shell="ci"),
        job_commands=Commands(test=("uv run x.py ci zizmor",)),
    ),
    StandaloneTask(
        id="l10n",
        trigger=(
            "apps/eve-fit-assistant/l10n.yaml",
            "apps/eve-fit-assistant/l10n/*.arb",
            "packages/efa_fit_snapshot/l10n.yaml",
            "packages/efa_fit_snapshot/l10n/*.arb",
        ),
        job_setup=Setup(shell="python"),
        job_commands=Commands(lint=("uv run x.py lint --check --lang l10n",)),
    ),
)


@dataclass(frozen=True)
class TaskInstance:
    """A task kind bound to one package (``None`` for standalone kinds).

    A batched instance (``batch`` non-empty) runs the selected small packages
    of one kind together on a single runner: setup phases run once, codegen
    is the union of the members' closures, and lint/test commands run per
    member in sequence.
    """

    kind: str
    package: str | None
    batch: tuple[str, ...] = ()

    @property
    def id(self) -> str:
        if self.batch:
            return f"{self.kind}:small"
        return self.kind if self.package is None else f"{self.kind}:{self.package}"

    def job_spec(self) -> dict:
        """Render this instance as a fully self-describing job specification."""
        setup: Setup
        commands: Commands
        if self.batch:
            setup, commands = self._batch_job()
        elif self.package is None:
            standalone = next(k for k in STANDALONE_KINDS if k.id == self.kind)
            setup = standalone.job_setup
            commands = standalone.job_commands
        else:
            package = next(p for p in PACKAGES if p.id == self.package)
            kind = next(k for k in TASK_KINDS if k.id == self.kind)
            setup = kind.setup(package)
            commands = kind.commands(package)

        def join(parts: tuple[str, ...]) -> str:
            return " && ".join(parts)

        return {
            "id": self.id,
            "slug": self.id.replace(":", "-"),
            "shell": setup.shell,
            "uv_sync": setup.uv_sync,
            "pub_get": setup.pub_get,
            "pnpm_install": setup.pnpm_install,
            "native_data": setup.native_data,
            "dev_env": setup.dev_env,
            "codegen": join(commands.codegen),
            "lint": join(commands.lint),
            "test": join(commands.test),
        }

    def _batch_job(self) -> tuple[Setup, Commands]:
        """Aggregate the batched members into one setup and command list."""
        by_id = {p.id: p for p in PACKAGES}
        members = [by_id[member] for member in self.batch]
        kind = next(k for k in TASK_KINDS if k.id == self.kind)

        member_setups = [kind.setup(member) for member in members]
        if len({s.shell for s in member_setups}) != 1:
            raise ValueError(f"Batched {self.kind} members disagree on the dev shell")
        setup = Setup(
            shell=member_setups[0].shell,
            uv_sync=any(s.uv_sync for s in member_setups),
            pub_get=any(s.pub_get for s in member_setups),
            pnpm_install=any(s.pnpm_install for s in member_setups),
            native_data=any(s.native_data for s in member_setups),
            dev_env=any(s.dev_env for s in member_setups),
        )

        steps = steps_for_packages(self.batch)
        codegen = (f"uv run x.py ci codegen --steps {','.join(steps)}",) if steps else ()
        member_commands = [kind.commands(member) for member in members]
        return setup, Commands(
            codegen=codegen,
            lint=tuple(cmd for c in member_commands for cmd in c.lint),
            test=tuple(cmd for c in member_commands for cmd in c.test),
        )


def applicable_kinds(package: Package) -> list[TaskKind]:
    """Every per-package task kind that instantiates for the package."""
    return [kind for kind in TASK_KINDS if kind.applies(package)]


def instantiate(
    packages: set[str] | frozenset[str], standalone: set[str] | frozenset[str]
) -> list[TaskInstance]:
    """Instantiate task kinds for the affected packages and standalone kinds.

    Selected small packages of one kind collapse into a single batched
    instance; large packages always instantiate dedicated tasks.
    """
    by_id = {p.id: p for p in PACKAGES}
    instances: list[TaskInstance] = []
    for kind in TASK_KINDS:
        members = sorted(p for p in packages if kind.applies(by_id[p]))
        small = [p for p in members if by_id[p].size == "small"]
        instances.extend(TaskInstance(kind=kind.id, package=p) for p in members if p not in small)
        if small:
            instances.append(TaskInstance(kind=kind.id, package=None, batch=tuple(small)))
    instances.extend(TaskInstance(kind=kind, package=None) for kind in sorted(standalone))
    return instances
