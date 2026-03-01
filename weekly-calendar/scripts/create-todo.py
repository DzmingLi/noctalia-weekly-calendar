#!/usr/bin/env python3
"""Create a VTODO item via Evolution Data Server."""

import argparse
import json
import sys
from datetime import datetime, timezone

import gi
gi.require_version("ECal", "2.0")
gi.require_version("EDataServer", "1.2")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, ICalGLib


def find_task_source(registry, task_list_uid):
    source = registry.ref_source(task_list_uid)
    if source and source.has_extension(EDataServer.SOURCE_EXTENSION_TASK_LIST):
        return source
    for src in registry.list_sources(EDataServer.SOURCE_EXTENSION_TASK_LIST):
        if src.get_display_name() == task_list_uid or src.get_uid() == task_list_uid:
            return src
    return None


def make_ical_datetime(timestamp):
    dt = datetime.fromtimestamp(timestamp, tz=timezone.utc).astimezone()
    ical_time = ICalGLib.Time.new_null_time()
    ical_time.set_date(dt.year, dt.month, dt.day)
    ical_time.set_time(dt.hour, dt.minute, dt.second)
    tz_id = dt.strftime("%Z")
    builtin_tz = ICalGLib.Timezone.get_builtin_timezone(tz_id)
    if builtin_tz:
        ical_time.set_timezone(builtin_tz)
    else:
        ical_time.set_timezone(ICalGLib.Timezone.get_utc_timezone())
    return ical_time


def main():
    parser = argparse.ArgumentParser(description="Create EDS VTODO item")
    parser.add_argument("--task-list", required=True, help="Task list UID")
    parser.add_argument("--summary", required=True, help="Task summary")
    parser.add_argument("--due", type=int, default=0, help="Due date (UNIX timestamp)")
    parser.add_argument("--priority", type=int, default=0, help="Priority (0-9)")
    parser.add_argument("--description", default="", help="Task description")
    args = parser.parse_args()

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
        source = find_task_source(registry, args.task_list)
        if not source:
            print(json.dumps({"success": False, "error": f"Task list not found: {args.task_list}"}))
            sys.exit(1)

        client = ECal.Client.connect_sync(
            source, ECal.ClientSourceType.TASKS, -1, None
        )

        comp = ICalGLib.Component.new(ICalGLib.ComponentKind.VTODO_COMPONENT)
        comp.set_summary(args.summary)
        comp.set_status(ICalGLib.PropertyStatus.NEEDSACTION)

        if args.due > 0:
            comp.set_due(make_ical_datetime(args.due))

        if args.priority > 0:
            prop = ICalGLib.Property.new_priority(args.priority)
            comp.add_property(prop)

        if args.description:
            comp.set_description(args.description)

        # Set PERCENT-COMPLETE to 0
        prop = ICalGLib.Property.new_percentcomplete(0)
        comp.add_property(prop)

        uid = client.create_object_sync(comp, ECal.OperationFlags.NONE, None)
        print(json.dumps({"success": True, "uid": uid}))

    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
