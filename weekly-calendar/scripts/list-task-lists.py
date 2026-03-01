#!/usr/bin/env python3
"""List task lists (VTODO sources) from Evolution Data Server."""

import json
import sys

import gi
gi.require_version("EDataServer", "1.2")
from gi.repository import EDataServer


def main():
    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
        task_lists = []

        for source in registry.list_sources(EDataServer.SOURCE_EXTENSION_TASK_LIST):
            task_lists.append({
                "uid": source.get_uid(),
                "name": source.get_display_name(),
                "enabled": source.get_enabled(),
            })

        print(json.dumps(task_lists))

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
