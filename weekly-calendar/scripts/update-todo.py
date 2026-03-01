#!/usr/bin/env python3
"""Update or delete a VTODO item via Evolution Data Server."""

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


def remove_property(comp, kind):
    """Remove all properties of the given kind from a component."""
    prop = comp.get_first_property(kind)
    while prop:
        comp.remove_property(prop)
        prop = comp.get_first_property(kind)


def main():
    parser = argparse.ArgumentParser(description="Update/delete EDS VTODO item")
    parser.add_argument("--task-list", required=True, help="Task list UID")
    parser.add_argument("--uid", required=True, help="VTODO UID")
    parser.add_argument("--action", required=True, choices=["complete", "uncomplete", "delete"],
                        help="Action to perform")
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

        if args.action == "delete":
            client.remove_object_sync(args.uid, None, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
            print(json.dumps({"success": True}))
            return

        # For complete/uncomplete, fetch the existing component first
        success, comp = client.get_object_sync(args.uid, None, None)
        if not success or not comp:
            print(json.dumps({"success": False, "error": "VTODO not found"}))
            sys.exit(1)

        ical = comp.get_icalcomponent()

        if args.action == "complete":
            ical.set_status(ICalGLib.PropertyStatus.COMPLETED)

            # Set PERCENT-COMPLETE to 100
            remove_property(ical, ICalGLib.PropertyKind.PERCENTCOMPLETE_PROPERTY)
            prop = ICalGLib.Property.new_percentcomplete(100)
            ical.add_property(prop)

            # Set COMPLETED timestamp
            remove_property(ical, ICalGLib.PropertyKind.COMPLETED_PROPERTY)
            now = datetime.now(timezone.utc)
            completed_time = ICalGLib.Time.new_null_time()
            completed_time.set_date(now.year, now.month, now.day)
            completed_time.set_time(now.hour, now.minute, now.second)
            completed_time.set_timezone(ICalGLib.Timezone.get_utc_timezone())
            prop = ICalGLib.Property.new_completed(completed_time)
            ical.add_property(prop)

        elif args.action == "uncomplete":
            ical.set_status(ICalGLib.PropertyStatus.NEEDSACTION)

            # Set PERCENT-COMPLETE to 0
            remove_property(ical, ICalGLib.PropertyKind.PERCENTCOMPLETE_PROPERTY)
            prop = ICalGLib.Property.new_percentcomplete(0)
            ical.add_property(prop)

            # Remove COMPLETED timestamp
            remove_property(ical, ICalGLib.PropertyKind.COMPLETED_PROPERTY)

        client.modify_object_sync(comp, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
        print(json.dumps({"success": True}))

    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
