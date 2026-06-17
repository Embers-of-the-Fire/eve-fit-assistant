"""Canonical JSON encoding wrapper for EFA V2 schema.

Uses the ``canonicaljson`` package (https://pypi.org/project/canonicaljson/)
to produce deterministic, minimal JSON suitable for content-addressed hashing.
"""

from __future__ import annotations

import canonicaljson

from pydantic import BaseModel


def encode_canonical_json(data: dict | list | BaseModel) -> bytes:
    """Encode *data* as canonical JSON bytes.

    Pydantic ``BaseModel`` instances are first converted to dicts with
    ``model_dump(by_alias=True)`` so that camelCase JSON keys are used.
    """
    if isinstance(data, BaseModel):
        data = data.model_dump(by_alias=True)
    return canonicaljson.encode_canonical_json(data)
