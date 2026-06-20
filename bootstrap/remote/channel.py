"""Channel enum — the canonical content stream labels.

Channels are content streams, not API versions. Two channels are defined:

- ``testing`` — bleeding-edge data for developers and early testers.
- ``stable`` — validated data for normal users.

Content flows from ``testing`` to ``stable`` via the ``./x remote promote`` command.
"""

from __future__ import annotations

from enum import StrEnum


class Channel(StrEnum):
    TESTING = "testing"
    STABLE = "stable"
