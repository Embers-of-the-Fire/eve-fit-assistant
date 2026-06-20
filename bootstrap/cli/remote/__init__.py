from __future__ import annotations

from typing import TYPE_CHECKING

from click_aliases import ClickAliasedGroup

from bootstrap.cli.remote.announce import register_remote_announce
from bootstrap.cli.remote.config import register_remote_config
from bootstrap.cli.remote.lifecycle import register_remote_lifecycle
from bootstrap.cli.remote.mock import register_remote_mock
from bootstrap.cli.remote.session import register_remote_session


if TYPE_CHECKING:
    import click


def register_remote_commands(cli_group: click.Group) -> None:
    @cli_group.group(cls=ClickAliasedGroup)
    def remote():
        """Remote content management — prepare, publish, validate, fetch, mock."""

    register_remote_config(remote)
    register_remote_session(remote)
    register_remote_announce(remote)
    register_remote_lifecycle(remote)
    register_remote_mock(remote)


__all__ = ["register_remote_commands"]
