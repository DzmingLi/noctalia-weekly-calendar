#!/usr/bin/env python3
"""Create a calendar event via Evolution Data Server (EDS)."""

import argparse
import json
import sys
from datetime import datetime, timezone

import gi
gi.require_version("ECal", "2.0")
gi.require_version("EDataServer", "1.2")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, ICalGLib


def find_source(registry, calendar_uid):
    source = registry.ref_source(calendar_uid)
    if source and source.has_extension(EDataServer.SOURCE_EXTENSION_CALENDAR):
        return source
    # Fallback: search by display name
    for src in registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR):
        if src.get_display_name() == calendar_uid or src.get_uid() == calendar_uid:
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
        ical_time.set_date(dt.year, dt.month, dt.day)
        ical_time.set_time(dt.hour, dt.minute, dt.second)
    return ical_time


def main():
    parser = argparse.ArgumentParser(description="Create EDS calendar event")
    parser.add_argument("--calendar", required=True, help="Calendar UID or display name")
    parser.add_argument("--summary", required=True, help="Event summary/title")
    parser.add_argument("--start", required=True, type=int, help="Start time (UNIX timestamp)")
    parser.add_argument("--end", required=True, type=int, help="End time (UNIX timestamp)")
    parser.add_argument("--location", default="", help="Event location")
    parser.add_argument("--description", default="", help="Event description")
    args = parser.parse_args()

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
        source = find_source(registry, args.calendar)
        if not source:
            print(json.dumps({"success": False, "error": f"Calendar not found: {args.calendar}"}))
            sys.exit(1)

        client = ECal.Client.connect_sync(
            source, ECal.ClientSourceType.EVENTS, -1, None
        )

        comp = ICalGLib.Component.new(ICalGLib.ComponentKind.VEVENT_COMPONENT)
        comp.set_summary(args.summary)
        comp.set_dtstart(make_ical_datetime(args.start))
        comp.set_dtend(make_ical_datetime(args.end))

        if args.location:
            comp.set_location(args.location)
        if args.description:
            comp.set_description(args.description)

        uid = client.create_object_sync(comp, ECal.OperationFlags.NONE, None)
        print(json.dumps({"success": True, "uid": uid}))

    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
