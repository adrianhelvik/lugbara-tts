import os

/// Lugbara's log. Read it with:
/// log show --predicate 'subsystem == "io.plenora.lugbara"' --info --last 10m
let log = Logger(subsystem: "io.plenora.lugbara", category: "reading")
