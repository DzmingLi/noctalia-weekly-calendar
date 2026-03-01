#!/usr/bin/env python3
"""List VTODO items from Evolution Data Server task lists."""

import argparse
import json
import sys
from datetime import datetime, timezone

import gi
gi.require_version("ECal", "2.0")
gi.require_version("EDataServer", "1.2")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, ICalGLib


def ical_time_to_iso(ical_time):
    """Convert ICalTime to ISO 8601 string, or None if null/invalid."""
    if not ical_time or ical_time.is_null_time():
        return None
    y = ical_time.get_year()
    m = ical_time.get_month()
    d = ical_time.get_day()
    h = ical_time.get_hour()
    mi = ical_time.get_minute()
    s = ical_time.get_second()
    try:
        dt = datetime(y, m, d, h, mi, s)
        return dt.isoformat()
    except (ValueError, OverflowError):
        return None


def get_status_string(status):
    mapping = {
        ICalGLib.PropertyStatus.NEEDSACTION: "NEEDS-ACTION",
        ICalGLib.PropertyStatus.COMPLETED: "COMPLETED",
        ICalGLib.PropertyStatus.INPROCESS: "IN-PROCESS",
        ICalGLib.PropertyStatus.CANCELLED: "CANCELLED",
    }
    return mapping.get(status, "NEEDS-ACTION")


def main():
    parser = argparse.ArgumentParser(description="List VTODO items from EDS")
    parser.add_argument("--include-completed", action="store_true",
                        help="Include completed tasks")
    args = parser.parse_args()

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
        todos = []

        for source in registry.list_sources(EDataServer.SOURCE_EXTENSION_TASK_LIST):
            if not source.get_enabled():
                continue

            try:
                client = ECal.Client.connect_sync(
                    source, ECal.ClientSourceType.TASKS, -1, None
                )
            except Exception:
                continue

            # #t matches all objects
            success, result = client.get_object_list_as_comps_sync("#t", None)
            if not success:
                continue

            cal_name = source.get_display_name()
            cal_uid = source.get_uid()

            for comp in result:
                if comp.get_vtype() != ECal.ComponentVType.TODO:
                    continue

                ical = comp.get_icalcomponent()
                status = get_status_string(ical.get_status())

                if not args.include_completed and status == "COMPLETED":
                    continue

                due = ical_time_to_iso(ical.get_due())
                dtstart = ical_time_to_iso(ical.get_dtstart())

                # Get percent-complete
                percent = 0
                prop = ical.get_first_property(ICalGLib.PropertyKind.PERCENTCOMPLETE_PROPERTY)
                if prop:
                    percent = prop.get_percentcomplete()

                # Get priority
                priority = ical.get_priority() if hasattr(ical, 'get_priority') else 0
                # Fallback: read priority property directly
                if priority == 0:
                    prop = ical.get_first_property(ICalGLib.PropertyKind.PRIORITY_PROPERTY)
                    if prop:
                        priority = prop.get_priority()

                todos.append({
                    "uid": ical.get_uid(),
                    "summary": ical.get_summary() or "",
                    "description": ical.get_description() or "",
                    "due": due,
                    "dtstart": dtstart,
                    "status": status,
                    "priority": priority,
                    "percentComplete": percent,
                    "calendarName": cal_name,
                    "calendarUid": cal_uid,
                })

        # Sort: non-null due dates first (ascending), then null-due items
        todos.sort(key=lambda t: (t["due"] is None, t["due"] or ""))

        print(json.dumps(todos))

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
