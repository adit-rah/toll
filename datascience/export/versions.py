"""Every artifact ever shipped, oldest first. All are kept in artifacts/; the last is the one the app carries."""

from . import v0, v1, v2

VERSIONS = (v0, v1, v2)
SHIPPED = VERSIONS[-1]
