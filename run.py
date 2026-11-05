#!/usr/bin/env python3
"""Atalho de execução sem instalar o pacote."""

from __future__ import annotations

import logging
import sys

from karaoke.cli import main
from karaoke.logging_setup import configure_logging

if __name__ == "__main__":
    try:
        configure_logging("--debug" in sys.argv)
    except Exception:
        pass
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception:
        logging.getLogger("karaoke.startup").exception(
            "Falha fatal durante a execução"
        )
        raise
