import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Services.UI
import Quickshell.Io
import qs.Services.System

Item {
    id: root
    property var pluginApi: null
    property date currentDate: new Date()
    property ListModel eventsModel: ListModel {}
    property ListModel allDayEventsModel: ListModel {}
    property var overlappingEventsData: ({})
    property bool isLoading: false
    property bool hasLoadedOnce: false
    // Defer UI refresh until CalendarService finishes loading to avoid flicker
    property bool pendingEventsUpdate: false
    property string syncStatus: ""
    property int lastKnownEventCount: 0

    // Todo support
    property ListModel todosModel: ListModel {}
    property var taskLists: []
    property bool todosLoading: false
    property bool showCompletedTodos: false
    
    property real dayColumnWidth: 120 * Style.uiScaleRatio
    property real allDaySectionHeight: 0 * Style.uiScaleRatio
    property var allDayEventsWithLayout: []

    property date weekStart: calculateWeekStart(currentDate, firstDayOfWeek)
    property date weekEnd: calculateWeekEnd(weekStart)
    property var weekDates: calculateWeekDates(weekStart)
    property string monthRangeText: formatMonthRangeText(weekDates)

    // Settings
    property string panelModeSetting: pluginApi?.pluginSettings?.panelMode || "attached"
    property string weekStartSetting: pluginApi?.pluginSettings?.weekStart || "1"
    property string timeFormatSetting: pluginApi?.pluginSettings?.timeFormat || "24h"
    property string lineColorTypeSetting: pluginApi?.pluginSettings?.lineColorType || "mOutline"
    property real hourLineOpacitySetting: pluginApi?.pluginSettings?.hourLineOpacity ?? 0.5
    property real dayLineOpacitySetting: pluginApi?.pluginSettings?.dayLineOpacity ?? 0.9

    readonly property int firstDayOfWeek: weekStartSetting === "0" ? 0 : 
                                        weekStartSetting === "1" ? 1 : 
                                        weekStartSetting === "6" ? 6 : I18n.locale.firstDayOfWeek

    readonly property bool use12hourFormat: timeFormatSetting === "12h" ? true : 
                                           timeFormatSetting === "24h" ? false : 
                                           Settings.data.location.use12hourFormat

    readonly property color lineColor: lineColorTypeSetting === "mOnSurfaceVariant" ? Color.mOnSurfaceVariant : Color.mOutline

    onWeekStartSettingChanged: if (hasLoadedOnce) Qt.callLater(refreshView)
    onTimeFormatSettingChanged: eventsModelChanged()
    onCurrentDateChanged: Qt.callLater(refreshView)
    onLineColorTypeSettingChanged: eventsModelChanged()
    onHourLineOpacitySettingChanged: eventsModelChanged()
    onDayLineOpacitySettingChanged: eventsModelChanged()

    // React to CalendarService signals (async event delivery)
    Connections {
        target: CalendarService
        function onAvailableChanged() {
            if (CalendarService.available) {
                Qt.callLater(loadEvents)
                Qt.callLater(loadTaskLists)
                Qt.callLater(loadTodos)
            } else {
                isLoading = false
                if (pluginApi) syncStatus = pluginApi.tr("panel.no_service")
            }
        }
        function onEventsChanged() {
            var count = CalendarService.events ? CalendarService.events.length : 0
            // If auto-refresh dropped event count significantly, re-request wide range
            if (hasLoadedOnce && !isLoading && lastKnownEventCount > 10 && count < lastKnownEventCount * 0.5) {
                console.log("[weekly-calendar] Auto-refresh narrowed events (" + count + " vs " + lastKnownEventCount + "), re-requesting wide range")
                Qt.callLater(loadEvents)
                return
            }
            lastKnownEventCount = Math.max(lastKnownEventCount, count)
            if (CalendarService.loading) {
                pendingEventsUpdate = true
            } else {
                Qt.callLater(updateEventsFromService)
            }
        }
        function onLoadingChanged() {
            if (!CalendarService.loading && isLoading) {
                pendingEventsUpdate = false
                Qt.callLater(updateEventsFromService)
            } else if (!CalendarService.loading && pendingEventsUpdate) {
                pendingEventsUpdate = false
                Qt.callLater(updateEventsFromService)
            }
        }
    }

    // Safety timeout: if CalendarService never signals back, stop spinning
    Timer {
        id: loadingTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            if (isLoading) {
                console.warn("[weekly-calendar] loading timeout, forcing update")
                updateEventsFromService()
            }
        }
    }

    // IPC
    IpcHandler {
        target: "plugin:weekly-calendar"
        function togglePanel() { pluginApi?.withCurrentScreen(s => pluginApi.togglePanel(s)) }
    }

    Component.onCompleted: {
        initializePluginSettings()
        // Process any cached events immediately
        if (CalendarService.events && CalendarService.events.length > 0) {
            Qt.callLater(updateEventsFromService)
        }
        if (CalendarService.available) {
            Qt.callLater(loadEvents)
            Qt.callLater(loadTaskLists)
            Qt.callLater(loadTodos)
        }
    }

    onPluginApiChanged: {
        initializePluginSettings()
        if (CalendarService.events && CalendarService.events.length > 0) {
            Qt.callLater(updateEventsFromService)
        }
        if (CalendarService.available) {
            Qt.callLater(loadEvents)
            Qt.callLater(loadTaskLists)
            Qt.callLater(loadTodos)
        }
    }

    function initializePluginSettings() {
        if (!pluginApi) return
        if (!pluginApi.pluginSettings.weekStart) {
            pluginApi.pluginSettings = {
                weekStart: "1", 
                timeFormat: "24h",
                lineColorType: "mOutline",
                hourLineOpacity: 0.5,
                dayLineOpacity: 1.0
            }
            pluginApi.saveSettings()
        }
    }

    function initializePlugin() {
        console.log("[weekly-calendar] initializePlugin called, CalendarService.available=" + CalendarService.available)
        if (!hasLoadedOnce && CalendarService.available) {
            loadEvents()
        } else {
            refreshView()
        }
    }

    // Re-filter existing events for the current week view (no new fetch)
    function refreshView() {
        if (!pluginApi) return
        if (CalendarService.events && CalendarService.events.length > 0) {
            updateEventsFromService()
        } else if (hasLoadedOnce) {
            clearEventModels()
            syncStatus = pluginApi.tr("panel.no_events")
        }
    }

    // Fetch events from EDS - requests a wide date range to cover past/future navigation
    function loadEvents() {
        if (!pluginApi) return
        if (!CalendarService.available) {
            syncStatus = pluginApi.tr("panel.no_service")
            console.log("[weekly-calendar] loadEvents: service not available")
            return
        }

        isLoading = true
        pendingEventsUpdate = false
        syncStatus = pluginApi.tr("panel.loading")

        // Request a wider range: 365 days behind, 365 days ahead
        // Covers roughly a full year in both directions so future months stay populated
        var daysAhead = 365
        var daysBehind = 365

        CalendarService.loadEvents(daysAhead, daysBehind)

        hasLoadedOnce = true
        loadingTimeout.restart()

        // If CalendarService already has events (cached), display them now
        if (CalendarService.events && CalendarService.events.length > 0) {
            Qt.callLater(updateEventsFromService)
        }
    }

    function updateEventsFromService() {
        if (!pluginApi) return
        loadingTimeout.stop()
        clearEventModels()

        if (!CalendarService.available) {
            syncStatus = pluginApi.tr("panel.no_service")
        } else if (!CalendarService.events?.length) {
            var todoStats = processTodosForWeek()
            if (todoStats.count > 0) {
                syncStatus = pluginApi.tr("panel.no_events") + ", " +
                    todoStats.count + " " + (todoStats.count === 1 ? pluginApi.tr("panel.task") : pluginApi.tr("panel.tasks"))
            } else {
                syncStatus = pluginApi.tr("panel.no_events")
            }
        } else {
            var stats = processCalendarEvents(CalendarService.events)
            var todoStats = processTodosForWeek()
            var parts = []
            parts.push(stats.timedCount === 1
                ? `${stats.timedCount} ${pluginApi.tr("panel.event")}`
                : `${stats.timedCount} ${pluginApi.tr("panel.events")}`)
            parts.push(`${stats.allDayCount} ${pluginApi.tr("panel.allday")}`)
            if (todoStats.count > 0)
                parts.push(todoStats.count + " " + (todoStats.count === 1 ? pluginApi.tr("panel.task") : pluginApi.tr("panel.tasks")))
            syncStatus = parts.join(", ")
        }

        isLoading = false
    }

    // Events generation & layout
    function processCalendarEvents(events) {
        var uniqueEvents = {}, uniqueAllDayEvents = {}
        var timedCount = 0, allDayCount = 0
        var newEvents = [], newAllDayEvents = []
        var weekStartDate = new Date(weekStart), weekEndDate = new Date(weekEnd)
        
        for (var i = 0; i < events.length; i++) {
            var event = events[i], eventObj = createEventObject(event, i)
            var eventStart = new Date(eventObj.startTime), eventEnd = new Date(eventObj.endTime)
            var overlapsWeek = eventStart < weekEndDate && eventEnd > weekStartDate
            
            if (overlapsWeek) {
                var key = event.uid + "-" + event.start + "-" + event.end
                if (eventObj.allDay) {
                    if (!uniqueAllDayEvents[key]) {
                        uniqueAllDayEvents[key] = true
                        allDayCount++
                        newAllDayEvents.push(eventObj)
                    }
                } else if (!uniqueEvents[key]) {
                    uniqueEvents[key] = true
                    timedCount++
                    processTimedEventIntoArray(eventObj, newEvents)
                }
            }
        }
        
        eventsModel.clear()
        allDayEventsModel.clear()
        newEvents.forEach(e => eventsModel.append(e))
        newAllDayEvents.forEach(e => allDayEventsModel.append(e))
        
        calculateAllDayEventLayout()
        updateOverlappingEvents()
        eventsModel.layoutChanged()
        allDayEventsModel.layoutChanged()
        
        return {timedCount: timedCount, allDayCount: allDayCount}
    }

    function processTodosForWeek() {
        var weekStartDate = new Date(weekStart)
        var weekEndDate = new Date(weekEnd)
        var count = 0

        for (var i = 0; i < todosModel.count; i++) {
            var todo = todosModel.get(i)
            if (!todo.due) continue

            var dueDate = new Date(todo.due)
            if (isNaN(dueDate.getTime())) continue
            if (dueDate < weekStartDate || dueDate >= weekEndDate) continue
            if (!showCompletedTodos && todo.status === "COMPLETED") continue

            var isDueAllDay = (dueDate.getHours() === 0 && dueDate.getMinutes() === 0)
            var endDate = isDueAllDay ? new Date(dueDate.getTime() + 86400000)
                                       : new Date(dueDate.getTime() + 1800000)

            var todoEvent = {
                id: "todo-" + todo.uid,
                title: todo.summary,
                description: todo.description || "",
                location: "",
                startTime: dueDate,
                endTime: endDate,
                allDay: isDueAllDay,
                multiDay: false,
                daySpan: 1,
                isTodo: true,
                todoUid: todo.uid,
                calendarUid: todo.calendarUid,
                todoStatus: todo.status,
                todoPriority: todo.priority,
            }

            if (isDueAllDay) {
                allDayEventsModel.append(todoEvent)
            } else {
                eventsModel.append(todoEvent)
            }
            count++
        }

        // Recalculate layouts after adding todos
        if (count > 0) {
            calculateAllDayEventLayout()
            updateOverlappingEvents()
            eventsModel.layoutChanged()
            allDayEventsModel.layoutChanged()
        }

        return { count: count }
    }

    function clearEventModels() { eventsModel.clear(); allDayEventsModel.clear() }

    function processTimedEventIntoArray(eventObj, target) {
        var start = new Date(eventObj.startTime), end = new Date(eventObj.endTime)
        var startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate())
        var endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate())
        
        if (startDay.getTime() === endDay.getTime()) {
            if (start < weekEnd && end > weekStart) target.push(createEventPart(eventObj, 0, start, end, startDay, 0, 1))
        } else {
            var firstEnd = new Date(startDay); firstEnd.setHours(24, 0, 0, 0)
            var secondStart = new Date(endDay); secondStart.setHours(0, 0, 0, 0)
            if (start < weekEnd && firstEnd > weekStart) target.push(createEventPart(eventObj, 0, start, firstEnd, startDay, 0, 2))
            if (secondStart < weekEnd && end > weekStart) target.push(createEventPart(eventObj, 1, secondStart, end, endDay, 1, 2))
        }
    }

    function createEventObject(event, idx) {
        var start = new Date(event.start * 1000), end = new Date(event.end * 1000)
        var allDay = isAllDayEvent(event), multiDay = isMultiDayEvent(event)
        var daySpan = calculateDaySpan(start, end, multiDay || allDay)
        var endsMidnight = end.getHours() === 0 && end.getMinutes() === 0 && end.getSeconds() === 0
        var id = event.uid + "-" + event.start + "-" + event.end + idx
        
        return {
            id: id, title: event.summary || "Untitled Event", description: event.description || "",
            location: event.location || "", startTime: start, endTime: end, allDay: allDay, multiDay: multiDay,
            daySpan: daySpan, rawStart: event.start, rawEnd: event.end, duration: (event.end - event.start) / 3600,
            endsAtMidnight: endsMidnight, isTodo: false, todoUid: "", calendarUid: "", todoStatus: "", todoPriority: 0
        }
    }

    function createEventPart(event, partIdx, start, end, day, partNum, total) {
        return {
            id: event.id + "-part-" + partIdx, title: event.title, description: event.description,
            location: event.location, startTime: start, endTime: end, allDay: false, multiDay: true,
            daySpan: 1, fullStartTime: event.startTime, fullEndTime: event.endTime, isPart: true,
            partDay: new Date(day), partIndex: partNum, totalParts: total,
            isTodo: false, todoUid: "", calendarUid: "", todoStatus: "", todoPriority: 0
        }
    }

    function getDayIndexForDate(date) {
        if (!date || isNaN(date.getTime())) return -1
        var diff = Math.floor((date - weekStart) / 86400000)
        return diff >= 0 && diff < 7 ? diff : -1
    }
    function getDisplayDayIndexForDate(date) { return getDayIndexForDate(date) }

    function calculateAllDaySpanForWeek(event) {
        var start = new Date(event.startTime), end = new Date(event.endTime)
        var endsMidnight = end.getHours() === 0 && end.getMinutes() === 0 && end.getSeconds() === 0
        var adjEnd = endsMidnight ? new Date(end.getTime() - 1) : end
        var startIdx = Math.max(0, getDayIndexForDate(start))
        var endIdx = Math.min(6, Math.floor((Math.min(adjEnd, weekEnd) - weekStart) / 86400000))
        return Math.max(1, endIdx - startIdx + 1)
    }

    function findAvailableLane(occupied, start, end) {
        var lane = 0, found = false
        while (!found) {
            var conflict = false
            for (var d = start; d <= end; d++) {
                if (occupied[d]?.includes(lane)) { conflict = true; break }
            }
            if (!conflict) found = true
            else lane++
        }
        return lane
    }

    function calculateAllDayEventLayout() {
        
        var occupied = [[], [], [], [], [], [], []]
        var eventsWithLayout = [], maxLanes = 0
        var weekStartDate = new Date(weekStart), weekEndDate = new Date(weekEnd)
        
        for (var i = 0; i < allDayEventsModel.count; i++) {
            var event = allDayEventsModel.get(i)
            var start = new Date(event.startTime), end = new Date(event.endTime)
            var startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate())
            var endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate())
            
            if (startDay < weekStartDate && endDay >= weekStartDate) {
                var span = calculateAllDaySpanForWeek(event)
                if (span > 0) {
                    var lane = findAvailableLane(occupied, 0, span - 1)
                    for (var d = 0; d < span && d < 7; d++) { if (!occupied[d]) occupied[d] = []; occupied[d].push(lane) }
                    maxLanes = Math.max(maxLanes, lane + 1)
                    eventsWithLayout.push(createLayoutEvent(event, 0, span, lane, true))
                }
            } else if (startDay >= weekStartDate && startDay < weekEndDate) {
                var startIdx = getDayIndexForDate(start)
                var span = calculateAllDaySpanForWeek(event)
                if (span > 0) {
                    var lane = findAvailableLane(occupied, startIdx, startIdx + span - 1)
                    for (var d = startIdx; d < startIdx + span && d < 7; d++) { if (!occupied[d]) occupied[d] = []; occupied[d].push(lane) }
                    maxLanes = Math.max(maxLanes, lane + 1)
                    eventsWithLayout.push(createLayoutEvent(event, startIdx, span, lane, false))
                }
            }
        }
        
        eventsWithLayout.sort((a,b) => a.lane !== b.lane ? a.lane - b.lane : a.startDay - b.startDay)
        allDayEventsWithLayout = eventsWithLayout
        allDaySectionHeight = maxLanes === 0 ? 0 : maxLanes === 1 ? 25 : Math.max(30, maxLanes * 25)
        
        return maxLanes
    }

    function createLayoutEvent(event, startDay, spanDays, lane, isCont) {
        return {
            id: event.id, title: event.title, description: event.description, location: event.location,
            startTime: event.startTime, endTime: event.endTime, allDay: event.allDay, multiDay: event.multiDay,
            daySpan: event.daySpan, rawStart: event.rawStart, rawEnd: event.rawEnd, duration: event.duration,
            endsAtMidnight: event.endsAtMidnight, fullStartTime: event.fullStartTime, fullEndTime: event.fullEndTime,
            startDay: startDay, spanDays: spanDays, lane: lane, isContinuation: isCont,
            isTodo: event.isTodo || false, todoUid: event.todoUid || "", calendarUid: event.calendarUid || "",
            todoStatus: event.todoStatus || "", todoPriority: event.todoPriority || 0
        }
    }

    function updateOverlappingEvents() {
        var overlapData = {}
        for (var day = 0; day < 7; day++) processDayEventsWithLanes(day, overlapData)
        overlappingEventsData = overlapData
    }

    function processDayEventsWithLanes(day, data) {
        var events = []
        for (var i = 0; i < eventsModel.count; i++) {
            var e = eventsModel.get(i)
            if (getDisplayDayIndexForDate(e.startTime) === day) {
                events.push({index: i, start: e.startTime.getTime(), end: e.endTime.getTime()})
            }
        }
        if (events.length === 0) return
        
        events.sort((a,b) => a.start === b.start ? (b.end - b.start) - (a.end - a.start) : a.start - b.start)
        var groups = [], current = [], endTime = -1
        
        events.forEach(e => {
            if (e.start >= endTime) {
                if (current.length > 0) groups.push({events: current, endTime: endTime})
                current = [e]; endTime = e.end
            } else {
                current.push(e)
                if (e.end > endTime) endTime = e.end
            }
        })
        if (current.length > 0) groups.push({events: current, endTime: endTime})
        groups.forEach(g => assignLanesToGroup(g.events, data))
    }

    function assignLanesToGroup(group, data) {
        if (group.length === 0) return
        var laneEnds = []
        group.forEach(e => {
            var placed = false
            for (var lane = 0; lane < laneEnds.length; lane++) {
                if (e.start >= laneEnds[lane]) {
                    laneEnds[lane] = e.end
                    e.lane = lane
                    placed = true
                    break
                }
            }
            if (!placed) { e.lane = laneEnds.length; laneEnds.push(e.end) }
        })
        
        var total = laneEnds.length
        group.forEach(e => {
            data[e.index] = {
                xOffset: (e.lane / total) * (dayColumnWidth +1),
                width: (dayColumnWidth+1) / total,
                lane: e.lane,
                totalLanes: total
            }
        })
    }

    // Range & formatting of calendar
    function calculateWeekStart(date, firstDay) {
        var d = new Date(date)
        var day = d.getDay()
        var diff = (day - firstDay + 7) % 7
        d.setDate(d.getDate() - diff)
        d.setHours(0, 0, 0, 0)
        return d
    }

    function calculateWeekDates(startDate) {
        var dates = []
        var start = new Date(startDate)
        
        for (var i = 0; i < 7; i++) {
            var d = new Date(start)
            d.setDate(start.getDate() + i)
            dates.push(d)
        }
        
        return dates
    }

    function calculateWeekEnd(startDate) {
        var end = new Date(startDate)
        end.setDate(end.getDate() + 7)
        end.setHours(0, 0, 0, 0)
        return end
    }

    function isSameDay(date1, date2) {
        return date1.getDate() === date2.getDate() &&
               date1.getMonth() === date2.getMonth() &&
               date1.getFullYear() === date2.getFullYear()
    }

    function isToday(date) {
        var today = new Date()
        return isSameDay(date, today)
    }

    function isDateInRange(date, startDate, endDate) {
        return date >= startDate && date < endDate
    }

    function formatMonthRangeText(dates) {
        if (!dates || dates.length === 0) return ""
        var start = dates[0], end = dates[6], locale = I18n.locale
        return locale.toString(start, "yyyy-MM") === locale.toString(end, "yyyy-MM") 
            ? locale.toString(start, "MMM yyyy")
            : start.getFullYear() === end.getFullYear()
                ? locale.toString(start, "MMM") + " – " + locale.toString(end, "MMM") + " " + start.getFullYear()
                : locale.toString(start, "MMM yyyy") + " – " + locale.toString(end, "MMM yyyy")
    }

    function isAllDayEvent(event) {
        var dur = event.end - event.start
        var start = new Date(event.start * 1000), end = new Date(event.end * 1000)
        var startsMidnight = start.getHours() === 0 && start.getMinutes() === 0 && start.getSeconds() === 0
        var endsMidnight = end.getHours() === 0 && end.getMinutes() === 0 && end.getSeconds() === 0
        return (dur === 86400 && startsMidnight) || (dur >= 86400 && endsMidnight) || dur >= 86400
    }

    function isMultiDayEvent(event) {
        var start = new Date(event.start * 1000), end = new Date(event.end * 1000)
        var endsMidnight = end.getHours() === 0 && end.getMinutes() === 0 && end.getSeconds() === 0
        var startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate())
        var endDay = endsMidnight ? new Date(end.getFullYear(), end.getMonth(), end.getDate() - 1) :
                                   new Date(end.getFullYear(), end.getMonth(), end.getDate())
        return startDay.getTime() !== endDay.getTime()
    }

    function calculateDaySpan(start, end, isMultiDay) {
        if (!isMultiDay) return 1
        var startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate())
        var endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate())
        var diff = Math.floor((endDay - startDay) / 86400000)
        var endsMidnight = end.getHours() === 0 && end.getMinutes() === 0 && end.getSeconds() === 0
        return Math.max(1, endsMidnight ? diff : diff + 1)
    }

    function formatTime(date) {
        if (!date || isNaN(date.getTime())) return ""
        return use12hourFormat ? I18n.locale.toString(date, "h:mm AP") : I18n.locale.toString(date, "HH:mm")
    }

    function formatDateTime(date) {
        if (!date || isNaN(date.getTime())) return ""
        return I18n.locale.monthName(date.getMonth(), Locale.ShortFormat) + ' ' + 
               date.getDate() + ', ' + date.getFullYear() + ' ' + formatTime(date)
    }

    function formatTimeRangeForDisplay(event) {
        var start = event.fullStartTime || event.startTime
        var end = event.fullEndTime || event.endTime
        return formatTime(start) + " - " + formatTime(end)
    }

    // Interaction functions
    function getEventTooltip(event) {
        var start = event.fullStartTime || event.startTime
        var end = event.fullEndTime || event.endTime
        var tip = event.title + "\n" + formatDateTime(start) + " - " + formatDateTime(end)
        if (event.location) tip += "\n⚲ " + event.location
        if (event.description) tip += "\n🛈 " + event.description
        return tip
    }

    function navigateWeek(days) {
        var d = new Date(currentDate)
        d.setDate(d.getDate() + days)
        currentDate = d
    }

    function handleEventClick(event) {
        const date = event.startTime || new Date();
        const month = date.getMonth() + 1;
        const day = date.getDate();
        const year = date.getFullYear();
        const dateWithSlashes = `${month.toString().padStart(2, '0')}/${day.toString().padStart(2, '0')}/${year.toString().substring(2)}`;
        if (ProgramCheckerService.gnomeCalendarAvailable) {
            Quickshell.execDetached(["gnome-calendar", "--date", dateWithSlashes]);
        }
    }

    function goToToday() { currentDate = new Date() }

    // Event creation via EDS Python script
    property string createEventStdout: ""
    property string createEventStderr: ""

    Process {
        id: createEventProcess
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                try {
                    var result = JSON.parse(createEventStdout)
                    if (result.success) {
                        console.log("Event created: " + result.uid)
                        Qt.callLater(loadEvents)
                    }
                } catch(e) {
                    console.error("Failed to parse create-event output: " + createEventStdout)
                }
            } else {
                console.error("create-event.py failed: " + createEventStderr)
            }
            createEventStdout = ""
            createEventStderr = ""
        }
        stdout: SplitParser {
            onRead: data => createEventStdout += data
        }
        stderr: SplitParser {
            onRead: data => createEventStderr += data
        }
    }

    function createEvent(calendarUid, summary, startTimestamp, endTimestamp, location, description) {
        var scriptPath = pluginApi.pluginDir + "/scripts/create-event.py"
        var args = ["python3", scriptPath,
                    "--calendar", calendarUid,
                    "--summary", summary,
                    "--start", String(startTimestamp),
                    "--end", String(endTimestamp)]
        if (location) { args.push("--location"); args.push(location) }
        if (description) { args.push("--description"); args.push(description) }
        createEventProcess.command = args
        createEventProcess.running = true
    }

    // === Todo support ===

    property string listTaskListsStdout: ""
    property string listTaskListsStderr: ""

    Process {
        id: listTaskListsProcess
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                try {
                    var result = JSON.parse(listTaskListsStdout)
                    if (Array.isArray(result)) {
                        taskLists = result.filter(function(tl) { return tl.enabled })
                    }
                } catch(e) {
                    console.error("[weekly-calendar] Failed to parse task lists: " + listTaskListsStdout)
                }
            } else {
                console.error("[weekly-calendar] list-task-lists.py failed: " + listTaskListsStderr)
            }
            listTaskListsStdout = ""
            listTaskListsStderr = ""
        }
        stdout: SplitParser { onRead: data => listTaskListsStdout += data }
        stderr: SplitParser { onRead: data => listTaskListsStderr += data }
    }

    property string listTodosStdout: ""
    property string listTodosStderr: ""

    Process {
        id: listTodosProcess
        onExited: function(exitCode, exitStatus) {
            todosLoading = false
            if (exitCode === 0) {
                try {
                    var result = JSON.parse(listTodosStdout)
                    if (Array.isArray(result)) {
                        todosModel.clear()
                        for (var i = 0; i < result.length; i++) {
                            todosModel.append(result[i])
                        }
                        // Re-process events to include updated todos on the calendar
                        Qt.callLater(updateEventsFromService)
                    }
                } catch(e) {
                    console.error("[weekly-calendar] Failed to parse todos: " + listTodosStdout)
                }
            } else {
                console.error("[weekly-calendar] list-todos.py failed: " + listTodosStderr)
            }
            listTodosStdout = ""
            listTodosStderr = ""
        }
        stdout: SplitParser { onRead: data => listTodosStdout += data }
        stderr: SplitParser { onRead: data => listTodosStderr += data }
    }

    property string createTodoStdout: ""
    property string createTodoStderr: ""

    Process {
        id: createTodoProcess
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                try {
                    var result = JSON.parse(createTodoStdout)
                    if (result.success) {
                        console.log("[weekly-calendar] Todo created: " + result.uid)
                        Qt.callLater(loadTodos)
                    }
                } catch(e) {
                    console.error("[weekly-calendar] Failed to parse create-todo output: " + createTodoStdout)
                }
            } else {
                console.error("[weekly-calendar] create-todo.py failed: " + createTodoStderr)
            }
            createTodoStdout = ""
            createTodoStderr = ""
        }
        stdout: SplitParser { onRead: data => createTodoStdout += data }
        stderr: SplitParser { onRead: data => createTodoStderr += data }
    }

    property string updateTodoStdout: ""
    property string updateTodoStderr: ""

    Process {
        id: updateTodoProcess
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                try {
                    var result = JSON.parse(updateTodoStdout)
                    if (result.success) {
                        console.log("[weekly-calendar] Todo updated")
                        Qt.callLater(loadTodos)
                    }
                } catch(e) {
                    console.error("[weekly-calendar] Failed to parse update-todo output: " + updateTodoStdout)
                }
            } else {
                console.error("[weekly-calendar] update-todo.py failed: " + updateTodoStderr)
            }
            updateTodoStdout = ""
            updateTodoStderr = ""
        }
        stdout: SplitParser { onRead: data => updateTodoStdout += data }
        stderr: SplitParser { onRead: data => updateTodoStderr += data }
    }

    function loadTaskLists() {
        if (!pluginApi) return
        var scriptPath = pluginApi.pluginDir + "/scripts/list-task-lists.py"
        listTaskListsProcess.command = ["python3", scriptPath]
        listTaskListsProcess.running = true
    }

    function loadTodos() {
        if (!pluginApi) return
        todosLoading = true
        todoSyncStatus = pluginApi.tr("panel.loading")
        var scriptPath = pluginApi.pluginDir + "/scripts/list-todos.py"
        var args = ["python3", scriptPath]
        if (showCompletedTodos) args.push("--include-completed")
        listTodosProcess.command = args
        listTodosProcess.running = true
    }

    function createTodo(taskListUid, summary, due, priority, description) {
        if (!pluginApi) return
        var scriptPath = pluginApi.pluginDir + "/scripts/create-todo.py"
        var args = ["python3", scriptPath,
                    "--task-list", taskListUid,
                    "--summary", summary]
        if (due > 0) { args.push("--due"); args.push(String(due)) }
        if (priority > 0) { args.push("--priority"); args.push(String(priority)) }
        if (description) { args.push("--description"); args.push(description) }
        createTodoProcess.command = args
        createTodoProcess.running = true
    }

    function completeTodo(taskListUid, todoUid) {
        if (!pluginApi) return
        var scriptPath = pluginApi.pluginDir + "/scripts/update-todo.py"
        updateTodoProcess.command = ["python3", scriptPath,
            "--task-list", taskListUid, "--uid", todoUid, "--action", "complete"]
        updateTodoProcess.running = true
    }

    function uncompleteTodo(taskListUid, todoUid) {
        if (!pluginApi) return
        var scriptPath = pluginApi.pluginDir + "/scripts/update-todo.py"
        updateTodoProcess.command = ["python3", scriptPath,
            "--task-list", taskListUid, "--uid", todoUid, "--action", "uncomplete"]
        updateTodoProcess.running = true
    }

    function deleteTodo(taskListUid, todoUid) {
        if (!pluginApi) return
        var scriptPath = pluginApi.pluginDir + "/scripts/update-todo.py"
        updateTodoProcess.command = ["python3", scriptPath,
            "--task-list", taskListUid, "--uid", todoUid, "--action", "delete"]
        updateTodoProcess.running = true
    }
}
