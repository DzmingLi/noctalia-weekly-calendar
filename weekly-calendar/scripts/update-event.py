#!/usr/bin/env python3
"""Update or delete a VEVENT item via Evolution Data Server."""

import argparse
import json
import sys
from datetime import datetime, timezone

import gi
gi.require_version("ECal", "2.0")
gi.require_version("EDataServer", "1.2")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, ICalGLib


def find_calendar_source(registry, calendar_uid):
    source = registry.ref_source(calendar_uid)
    if source and source.has_extension(EDataServer.SOURCE_EXTENSION_CALENDAR):
        return source
    for src in registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR):
        if src.get_display_name() == calendar_uid or src.get_uid() == calendar_uid:
            return src
    return None


def remove_property(comp, kind):
    """Remove all properties of the given kind from a component."""
    prop = comp.get_first_property(kind)
    while prop:
        comp.remove_property(prop)
        prop = comp.get_first_property(kind)


def main():
    parser = argparse.ArgumentParser(description="Update/delete EDS VEVENT item")
    parser.add_argument("--calendar", required=True, help="Calendar source UID")
    parser.add_argument("--uid", required=True, help="VEVENT UID")
    parser.add_argument("--action", required=True, choices=["delete", "update"],
                        help="Action to perform")
    parser.add_argument("--summary", help="New event summary")
    parser.add_argument("--location", help="New event location")
    parser.add_argument("--description", help="New event description")
    parser.add_argument("--start", type=int, help="New start time (unix timestamp)")
    parser.add_argument("--end", type=int, help="New end time (unix timestamp)")
    args = parser.parse_args()

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
        source = find_calendar_source(registry, args.calendar)
        if not source:
            print(json.dumps({"success": False, "error": f"Calendar not found: {args.calendar}"}))
            sys.exit(1)

        client = ECal.Client.connect_sync(
            source, ECal.ClientSourceType.EVENTS, 1, None
        )

        if args.action == "delete":
            client.remove_object_sync(args.uid, None, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
            print(json.dumps({"success": True}))
            return

        # For update, fetch the existing component first
        success, comp = client.get_object_sync(args.uid, None, None)
        if not success or not comp:
            print(json.dumps({"success": False, "error": "VEVENT not found"}))
            sys.exit(1)

        ical = comp.get_icalcomponent()

        if args.summary is not None:
            ical.set_summary(args.summary)

        if args.location is not None:
            ical.set_location(args.location)

        if args.description is not None:
            ical.set_description(args.description)

        if args.start is not None:
            dt = datetime.fromtimestamp(args.start, tz=timezone.utc)
            t = ICalGLib.Time.new_null_time()
            t.set_date(dt.year, dt.month, dt.day)
            t.set_time(dt.hour, dt.minute, dt.second)
            t.set_timezone(ICalGLib.Timezone.get_utc_timezone())
            ical.set_dtstart(t)

        if args.end is not None:
            dt = datetime.fromtimestamp(args.end, tz=timezone.utc)
            t = ICalGLib.Time.new_null_time()
            t.set_date(dt.year, dt.month, dt.day)
            t.set_time(dt.hour, dt.minute, dt.second)
            t.set_timezone(ICalGLib.Timezone.get_utc_timezone())
            ical.set_dtend(t)

        client.modify_object_sync(comp, ECal.ObjModType.ALL, ECal.OperationFlags.NONE, None)
        print(json.dumps({"success": True}))

    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
