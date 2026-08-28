from __future__ import annotations

import os
import re
import shutil

import click

from colorama import Fore
from colorama import Style

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.constant import EFA_APP_ROOT
from bootstrap.monorepo import PACKAGES
from bootstrap.utils import get_command
from bootstrap.utils import get_melos_command


_TEST_ON = re.compile(r"@TestOn\(\s*[\"']([^\"']*)[\"']\s*\)")
_PLATFORM_IMPORT = re.compile(r"""^import\s+["']dart:(?:io|ffi)["']""", re.MULTILINE)

_WEB_SQLITE_ASSETS = ("db_worker.js", "sqlite3.wasm")

_PACKAGES_BY_ID = {p.id: p for p in PACKAGES}

# Shared click options for change-aware test selection.
_SCOPE_OPTIONS = [
    click.option(
        "--changed",
        is_flag=True,
        default=False,
        help="Only test packages affected by changes since the base ref.",
    ),
    click.option(
        "--base-ref",
        default=None,
        help="Git ref to diff against (default: merge-base with origin/dev).",
    ),
    click.option(
        "--packages",
        default=None,
        help="Comma-separated monorepo package ids to restrict testing to.",
    ),
]


def _with_scope_options(func):
    for option in _SCOPE_OPTIONS:
        func = option(func)
    return func


def _is_vm_only_expression(expr: str) -> bool:
    """Whether a ``@TestOn`` expression restricts the suite to the VM.

    Compound expressions like ``vm && !windows`` still require the VM; only
    an expression with a ``||`` alternative that does not mention ``vm``
    (e.g. ``vm || browser``) can run on the web.
    """
    return all("vm" in clause for clause in expr.split("||"))


def _collect_web_test_suites() -> list[str]:
    """Collect test suites compilable for the web platform.

    The web test pipeline compiles every selected suite, so VM-only suites
    (which may import ``dart:ffi``/``dart:io``-only libraries) must be
    excluded from the selection instead of relying on ``@TestOn`` filtering.
    """
    test_root = EFA_APP_ROOT / "test"
    suites: list[str] = []
    for path in sorted(test_root.rglob("*_test.dart")):
        content = path.read_text(encoding="utf-8")
        match = _TEST_ON.search(content)
        if match is not None and _is_vm_only_expression(match.group(1)):
            continue
        if _PLATFORM_IMPORT.search(content):
            raise click.ClickException(
                f"{path.relative_to(EFA_APP_ROOT)} imports dart:io/dart:ffi but is not "
                'tagged @TestOn("vm"); it would break the web test compile'
            )
        suites.append(str(path.relative_to(EFA_APP_ROOT)))
    return suites


def _stage_web_sqlite_assets() -> None:
    """Copy the sqlite web worker assets into the served ``test/`` tree.

    The flutter web test server only serves the project's ``test/`` directory
    (at the server root), so the sqlite3 worker bundle shipped under
    ``web/sqlite/`` for production builds is mirrored to ``test/web/sqlite/``
    where web tests can fetch it.
    """
    source = EFA_APP_ROOT / "web" / "sqlite"
    target = EFA_APP_ROOT / "test" / "web" / "sqlite"
    missing = [name for name in _WEB_SQLITE_ASSETS if not (source / name).is_file()]
    if missing:
        raise click.ClickException(
            "web/sqlite assets missing: " + ", ".join(str(source / name) for name in missing)
        )
    target.mkdir(parents=True, exist_ok=True)
    for name in _WEB_SQLITE_ASSETS:
        shutil.copy2(source / name, target / name)


def register_test_commands(cli_group: click.Group) -> None:
    @cli_group.group()
    def test():
        """Run project test suites."""

    @test.command("python")
    def test_python():
        """Run Python tests via pytest."""
        uv = get_command("uv")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + "uv run pytest bootstrap/tests/"
        )
        runtime.execute([uv, "run", "pytest", "bootstrap/tests/"], "PYTEST OUTPUT")

    @test.command("dart")
    @_with_scope_options
    def test_dart(changed: bool, base_ref: str | None, packages: str | None):
        """Run Flutter/Dart tests.

        With ``--changed``/``--packages``, runs ``flutter test`` only in the
        affected workspace packages that have test suites.
        """
        package_ids, _ = runtime.resolve_change_scope(changed, base_ref, packages)
        scope = (
            None
            if package_ids is None
            else sorted(p for p in package_ids if _PACKAGES_BY_ID[p].ecosystem == "dart")
        )
        if scope is None:
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "melos run app:test"
            )
            runtime.run_melos("app:test", "FLUTTER TEST OUTPUT")
            return
        testable = [p for p in scope if _PACKAGES_BY_ID[p].tests]
        if not testable:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "No affected Dart packages with tests."))
            return
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + f"melos exec --scope=<{len(testable)} affected> -- flutter test"
        )
        scopes = [f"--scope={p}" for p in testable]
        runtime.execute(
            [*get_melos_command(), "exec", *scopes, "--", "flutter", "test"],
            "FLUTTER TEST OUTPUT",
        )

    @test.command("web")
    @_with_scope_options
    def test_web(changed: bool, base_ref: str | None, packages: str | None):
        """Run Flutter/Dart tests on the web platform in headless Chrome.

        Suites are compiled to JS (no ``--wasm``): the flutter web test harness
        cannot run sqlite3_web under dart2wasm in headless Chrome (dedicated
        workers and OPFS sync access handles are unavailable there), while the
        JS build exercises the real worker + OPFS path. VM-only suites are
        excluded from the selection because the web test pipeline compiles
        every selected suite regardless of ``@TestOn``, and those suites import
        ``dart:ffi``-only libraries.

        With ``--changed``/``--packages``, the run is skipped unless the app
        package itself is affected.
        """
        package_ids, _ = runtime.resolve_change_scope(changed, base_ref, packages)
        if package_ids is not None and "eve_fit_assistant" not in package_ids:
            click.echo(
                styled(
                    [Style.BRIGHT, Fore.YELLOW],
                    "App package not affected; skipping web tests.",
                )
            )
            return

        chrome = os.environ.get("CHROME_EXECUTABLE")
        if not chrome:
            for candidate in ("google-chrome", "chromium", "chrome"):
                chrome = shutil.which(candidate)
                if chrome:
                    break
        if not chrome:
            raise click.ClickException(
                "Chrome not found. Set CHROME_EXECUTABLE or install google-chrome/chromium."
            )
        os.environ["CHROME_EXECUTABLE"] = chrome

        suites = _collect_web_test_suites()
        if not suites:
            raise click.ClickException("No web-compatible test suites found under test/.")
        if not runtime.is_dry_run():
            _stage_web_sqlite_assets()

        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + "melos run app:test -- --platform chrome"
        )
        runtime.run_melos(
            "app:test", "FLUTTER WEB TEST OUTPUT", args=["--platform", "chrome", *suites]
        )

    @test.command("js")
    @_with_scope_options
    def test_js(changed: bool, base_ref: str | None, packages: str | None):
        """Run JS/TS tests (Vitest, incl. the Cloudflare Workers suites).

        With ``--changed``/``--packages``, runs ``pnpm --filter <id> test``
        only for the affected packages that define a test script.
        """
        package_ids, _ = runtime.resolve_change_scope(changed, base_ref, packages)
        pnpm = get_command("pnpm")
        if package_ids is None:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "pnpm test:js")
            runtime.execute([pnpm, "test:js"], "VITEST OUTPUT")
            return
        testable = [
            p
            for p in package_ids
            if p in _PACKAGES_BY_ID
            and _PACKAGES_BY_ID[p].ecosystem == "ts"
            and _PACKAGES_BY_ID[p].tests
        ]
        if not testable:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "No affected TS packages with tests."))
            return
        cmd = [pnpm]
        for package_id in sorted(testable):
            cmd += ["--filter", package_id]
        cmd.append("test")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + " ".join(cmd[1:]))
        runtime.execute(cmd, "VITEST OUTPUT")

    @test.command("all")
    @_with_scope_options
    @click.pass_context
    def test_all(ctx: click.Context, changed: bool, base_ref: str | None, packages: str | None):
        """Run all test suites (Python + Dart + Web + JS)."""
        package_ids, _ = runtime.resolve_change_scope(changed, base_ref, packages)
        scope = ",".join(package_ids) if package_ids is not None else None
        ctx.invoke(test_python)
        click.echo()
        ctx.invoke(test_dart, changed=False, base_ref=None, packages=scope)
        click.echo()
        ctx.invoke(test_web, changed=False, base_ref=None, packages=scope)
        click.echo()
        ctx.invoke(test_js, changed=False, base_ref=None, packages=scope)
