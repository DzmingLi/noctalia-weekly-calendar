import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 950 * Style.uiScaleRatio
    property real contentPreferredHeight: 700 * Style.uiScaleRatio
    property real topHeaderHeight: 60 * Style.uiScaleRatio
    readonly property bool allowAttach: mainInstance ? mainInstance.panelModeSetting === "attached" : false
    readonly property bool panelAnchorHorizontalCenter: mainInstance ? mainInstance.panelModeSetting === "centered" : false
    readonly property bool panelAnchorVerticalCenter: mainInstance ? mainInstance.panelModeSetting === "centered" : false
    anchors.fill: parent

    property bool showCreateDialog: false
    property bool showCreateTaskDialog: false
    property int currentTab: 0 // 0 = Calendar, 1 = Tasks

    property real hourHeight: 50 * Style.uiScaleRatio
    property real timeColumnWidth: 65 * Style.uiScaleRatio
    property real daySpacing: 1 * Style.uiScaleRatio

    // Panel doesn't need its own CalendarService connection - Main.qml handles it.
    // When panel opens, trigger a fresh load if needed.
    Component.onCompleted: mainInstance?.initializePlugin()
    onVisibleChanged: if (visible && mainInstance) {
        mainInstance.refreshView()
        mainInstance.goToToday()
        Qt.callLater(root.scrollToCurrentTime)
        if (currentTab === 1) mainInstance.loadTodos()
    }

    // Scroll to time indicator position
    function scrollToCurrentTime() {
        if (!mainInstance || !calendarFlickable) return
        var now = new Date(), today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var weekStart = new Date(mainInstance.weekStart)
        var weekEnd = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + 7)

        if (today >= weekStart && today < weekEnd) {
            var currentHour = now.getHours() + now.getMinutes() / 60
            var scrollPos = (currentHour * hourHeight) - (calendarFlickable.height / 2)
            var maxScroll = Math.max(0, (24 * hourHeight) - calendarFlickable.height)
            scrollAnim.targetY = Math.max(0, Math.min(scrollPos, maxScroll))
            scrollAnim.start()
        }
    }

    function formatTodoDueDate(dueStr) {
        if (!dueStr) return ""
        var due = new Date(dueStr)
        if (isNaN(due.getTime())) return ""
        var now = new Date()
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var dueDay = new Date(due.getFullYear(), due.getMonth(), due.getDate())
        var diffDays = Math.floor((dueDay - today) / 86400000)
        if (diffDays < 0) return pluginApi.tr("panel.overdue")
        if (diffDays === 0) return pluginApi.tr("panel.today")
        return I18n.locale.toString(due, "MMM d")
    }

    function isTodoOverdue(dueStr, status) {
        if (!dueStr || status === "COMPLETED") return false
        var due = new Date(dueStr)
        return due < new Date()
    }

    function priorityColor(priority) {
        if (priority >= 1 && priority <= 4) return Color.mError
        if (priority === 5) return Color.mTertiary
        if (priority >= 6 && priority <= 9) return Color.mPrimary
        return "transparent"
    }

    // Event creation dialog
    Rectangle {
        id: createEventOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: showCreateDialog
        z: 2000

        MouseArea { anchors.fill: parent; onClicked: showCreateDialog = false }

        Rectangle {
            anchors.centerIn: parent
            width: 400 * Style.uiScaleRatio
            height: createDialogColumn.implicitHeight + 2 * Style.marginM
            color: Color.mSurface
            radius: Style.radiusM

            MouseArea { anchors.fill: parent } // block clicks through

            ColumnLayout {
                id: createDialogColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                NText {
                    text: pluginApi.tr("panel.add_event")
                    font.pointSize: Style.fontSizeL; font.weight: Font.Bold
                    color: Color.mOnSurface
                }

                NText { text: pluginApi.tr("panel.summary"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createEventSummary
                    Layout.fillWidth: true
                    placeholderText: pluginApi.tr("panel.summary")
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                NText { text: pluginApi.tr("panel.date"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createEventDate
                    Layout.fillWidth: true
                    placeholderText: "YYYY-MM-DD"
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                RowLayout {
                    spacing: Style.marginS
                    ColumnLayout {
                        Layout.fillWidth: true
                        NText { text: pluginApi.tr("panel.start_time"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                        TextField {
                            id: createEventStartTime
                            Layout.fillWidth: true
                            placeholderText: "HH:MM"
                            color: Color.mOnSurface
                            background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        NText { text: pluginApi.tr("panel.end_time"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                        TextField {
                            id: createEventEndTime
                            Layout.fillWidth: true
                            placeholderText: "HH:MM"
                            color: Color.mOnSurface
                            background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                        }
                    }
                }

                NText { text: pluginApi.tr("panel.location"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createEventLocation
                    Layout.fillWidth: true
                    placeholderText: pluginApi.tr("panel.location")
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                NText { text: pluginApi.tr("panel.description"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createEventDescription
                    Layout.fillWidth: true
                    placeholderText: pluginApi.tr("panel.description")
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                NText { text: pluginApi.tr("panel.calendar_select"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                ComboBox {
                    id: calendarSelector
                    Layout.fillWidth: true
                    model: CalendarService.calendars || []
                    textRole: "name"
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: cancelBtn.implicitWidth + 2 * Style.marginM
                        Layout.preferredHeight: cancelBtn.implicitHeight + Style.marginS
                        color: Color.mSurfaceVariant; radius: Style.radiusS
                        NText {
                            id: cancelBtn; anchors.centerIn: parent
                            text: pluginApi.tr("panel.cancel"); color: Color.mOnSurfaceVariant
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showCreateDialog = false }
                    }

                    Rectangle {
                        Layout.preferredWidth: createBtn.implicitWidth + 2 * Style.marginM
                        Layout.preferredHeight: createBtn.implicitHeight + Style.marginS
                        color: Color.mPrimary; radius: Style.radiusS
                        opacity: createEventSummary.text.trim() !== "" ? 1.0 : 0.5
                        NText {
                            id: createBtn; anchors.centerIn: parent
                            text: pluginApi.tr("panel.create"); color: Color.mOnPrimary; font.weight: Font.Bold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (createEventSummary.text.trim() === "") return
                                var cal = CalendarService.calendars?.[calendarSelector.currentIndex]
                                var calUid = cal?.uid || ""
                                var dateParts = createEventDate.text.split("-")
                                var startParts = createEventStartTime.text.split(":")
                                var endParts = createEventEndTime.text.split(":")
                                var startDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1])-1, parseInt(dateParts[2]),
                                                         parseInt(startParts[0]), parseInt(startParts[1]), 0)
                                var endDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1])-1, parseInt(dateParts[2]),
                                                       parseInt(endParts[0]), parseInt(endParts[1]), 0)
                                mainInstance?.createEvent(calUid, createEventSummary.text.trim(),
                                    Math.floor(startDate.getTime()/1000), Math.floor(endDate.getTime()/1000),
                                    createEventLocation.text.trim(), createEventDescription.text.trim())
                                showCreateDialog = false
                            }
                        }
                    }
                }
            }
        }
    }

    // Task creation dialog
    Rectangle {
        id: createTaskOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: showCreateTaskDialog
        z: 2000

        MouseArea { anchors.fill: parent; onClicked: showCreateTaskDialog = false }

        Rectangle {
            anchors.centerIn: parent
            width: 400 * Style.uiScaleRatio
            height: createTaskDialogColumn.implicitHeight + 2 * Style.marginM
            color: Color.mSurface
            radius: Style.radiusM

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: createTaskDialogColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                NText {
                    text: pluginApi.tr("panel.add_task")
                    font.pointSize: Style.fontSizeL; font.weight: Font.Bold
                    color: Color.mOnSurface
                }

                NText { text: pluginApi.tr("panel.task_summary"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createTaskSummary
                    Layout.fillWidth: true
                    placeholderText: pluginApi.tr("panel.task_summary")
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                NText { text: pluginApi.tr("panel.due_date"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createTaskDueDate
                    Layout.fillWidth: true
                    placeholderText: "YYYY-MM-DD HH:MM"
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                NText { text: pluginApi.tr("panel.description"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createTaskDescription
                    Layout.fillWidth: true
                    placeholderText: pluginApi.tr("panel.description")
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                NText { text: pluginApi.tr("panel.priority"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                property int selectedPriority: 0
                RowLayout {
                    spacing: Style.marginS
                    Repeater {
                        model: [
                            { label: pluginApi.tr("panel.priority_high"), value: 1 },
                            { label: pluginApi.tr("panel.priority_medium"), value: 5 },
                            { label: pluginApi.tr("panel.priority_low"), value: 9 }
                        ]
                        Rectangle {
                            Layout.preferredWidth: priLabel.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: priLabel.implicitHeight + Style.marginS
                            color: createTaskDialogColumn.selectedPriority === modelData.value ? Color.mPrimary : Color.mSurfaceVariant
                            radius: Style.radiusS
                            NText {
                                id: priLabel; anchors.centerIn: parent
                                text: modelData.label
                                color: createTaskDialogColumn.selectedPriority === modelData.value ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: createTaskDialogColumn.selectedPriority =
                                    createTaskDialogColumn.selectedPriority === modelData.value ? 0 : modelData.value
                            }
                        }
                    }
                }

                NText { text: pluginApi.tr("panel.task_list_select"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                ComboBox {
                    id: taskListSelector
                    Layout.fillWidth: true
                    model: mainInstance?.taskLists || []
                    textRole: "name"
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: taskCancelBtn.implicitWidth + 2 * Style.marginM
                        Layout.preferredHeight: taskCancelBtn.implicitHeight + Style.marginS
                        color: Color.mSurfaceVariant; radius: Style.radiusS
                        NText {
                            id: taskCancelBtn; anchors.centerIn: parent
                            text: pluginApi.tr("panel.cancel"); color: Color.mOnSurfaceVariant
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showCreateTaskDialog = false }
                    }

                    Rectangle {
                        Layout.preferredWidth: taskCreateBtn.implicitWidth + 2 * Style.marginM
                        Layout.preferredHeight: taskCreateBtn.implicitHeight + Style.marginS
                        color: Color.mPrimary; radius: Style.radiusS
                        opacity: createTaskSummary.text.trim() !== "" ? 1.0 : 0.5
                        NText {
                            id: taskCreateBtn; anchors.centerIn: parent
                            text: pluginApi.tr("panel.create"); color: Color.mOnPrimary; font.weight: Font.Bold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (createTaskSummary.text.trim() === "") return
                                var tl = mainInstance?.taskLists?.[taskListSelector.currentIndex]
                                var tlUid = tl?.uid || ""
                                var dueTs = 0
                                if (createTaskDueDate.text.trim() !== "") {
                                    var d = new Date(createTaskDueDate.text.trim())
                                    if (!isNaN(d.getTime())) dueTs = Math.floor(d.getTime() / 1000)
                                }
                                mainInstance?.createTodo(tlUid, createTaskSummary.text.trim(),
                                    dueTs, createTaskDialogColumn.selectedPriority,
                                    createTaskDescription.text.trim())
                                showCreateTaskDialog = false
                            }
                        }
                    }
                }
            }
        }
    }

    // UI
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            //Header Section
            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: topHeaderHeight
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                RowLayout {
                    anchors.margins: Style.marginM
                    anchors.fill: parent

                    NIcon { icon: currentTab === 0 ? "calendar-week" : "clipboard-check"; pointSize: Style.fontSizeXXL; color: Color.mPrimary }

                    ColumnLayout {
                        Layout.fillHeight: true
                        spacing: 0
                        NText {
                            text: pluginApi.tr("panel.header")
                            font.pointSize: Style.fontSizeL; font.weight: Font.Bold; color: Color.mOnSurface
                        }
                        RowLayout {
                            spacing: Style.marginS
                            NText {
                                text: currentTab === 0 ? (mainInstance?.monthRangeText || "") : (mainInstance?.todoSyncStatus || "")
                                font.pointSize: Style.fontSizeS; font.weight: Font.Medium; color: Color.mOnSurfaceVariant
                            }
                            Rectangle {
                                Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                color: {
                                    if (currentTab === 0) {
                                        return mainInstance?.isLoading ? Color.mError :
                                               mainInstance?.syncStatus?.includes("No") ? Color.mError : Color.mOnSurfaceVariant
                                    } else {
                                        return mainInstance?.todosLoading ? Color.mError : Color.mOnSurfaceVariant
                                    }
                                }
                            }
                            NText {
                                text: currentTab === 0 ? (mainInstance?.syncStatus || "") : ""
                                font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: Style.marginS
                        // Calendar-specific buttons
                        NIconButton {
                            visible: currentTab === 0
                            icon: "plus"; tooltipText: pluginApi.tr("panel.add_event")
                            onClicked: {
                                createEventSummary.text = ""
                                createEventLocation.text = ""
                                createEventDescription.text = ""
                                var now = new Date()
                                var startH = now.getHours() + 1
                                createEventDate.text = now.getFullYear() + "-" + String(now.getMonth()+1).padStart(2,'0') + "-" + String(now.getDate()).padStart(2,'0')
                                createEventStartTime.text = String(startH).padStart(2,'0') + ":00"
                                createEventEndTime.text = String(startH+1).padStart(2,'0') + ":00"
                                showCreateDialog = true
                            }
                        }
                        NIconButton {
                            visible: currentTab === 0
                            icon: "chevron-left"
                            onClicked: mainInstance?.navigateWeek(-7)
                        }
                        NIconButton {
                            visible: currentTab === 0
                            icon: "calendar"; tooltipText: pluginApi.tr("panel.today")
                            onClicked: { mainInstance?.goToToday(); Qt.callLater(root.scrollToCurrentTime) }
                        }
                        NIconButton {
                            visible: currentTab === 0
                            icon: "chevron-right"
                            onClicked: mainInstance?.navigateWeek(7)
                        }
                        // Tasks-specific buttons
                        NIconButton {
                            visible: currentTab === 1
                            icon: "plus"; tooltipText: pluginApi.tr("panel.add_task")
                            onClicked: {
                                createTaskSummary.text = ""
                                createTaskDueDate.text = ""
                                createTaskDescription.text = ""
                                createTaskDialogColumn.selectedPriority = 0
                                showCreateTaskDialog = true
                            }
                        }
                        NIconButton {
                            visible: currentTab === 1
                            icon: mainInstance?.showCompletedTodos ? "eye-off" : "eye"
                            tooltipText: pluginApi.tr("panel.show_completed")
                            onClicked: {
                                if (mainInstance) {
                                    mainInstance.showCompletedTodos = !mainInstance.showCompletedTodos
                                    mainInstance.loadTodos()
                                }
                            }
                        }
                        // Shared buttons
                        NIconButton {
                            icon: "refresh"; tooltipText: I18n.tr("common.refresh")
                            onClicked: {
                                if (currentTab === 0) mainInstance?.loadEvents()
                                else mainInstance?.loadTodos()
                            }
                            enabled: currentTab === 0 ? (mainInstance ? !mainInstance.isLoading : false)
                                                      : (mainInstance ? !mainInstance.todosLoading : false)
                        }
                        NIconButton {
                            icon: "close"; tooltipText: I18n.tr("common.close")
                            onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                        }
                    }
                }
            }

            // Tab Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36 * Style.uiScaleRatio
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    Repeater {
                        model: [
                            { text: pluginApi.tr("panel.calendar_tab"), icon: "calendar", idx: 0 },
                            { text: pluginApi.tr("panel.tasks_tab"), icon: "clipboard-check", idx: 1 }
                        ]
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: currentTab === modelData.idx ? Color.mSurface : "transparent"
                            radius: Style.radiusS

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Style.marginS
                                NIcon {
                                    icon: modelData.icon
                                    pointSize: Style.fontSizeS
                                    color: currentTab === modelData.idx ? Color.mPrimary : Color.mOnSurfaceVariant
                                }
                                NText {
                                    text: modelData.text
                                    color: currentTab === modelData.idx ? Color.mPrimary : Color.mOnSurfaceVariant
                                    font.pointSize: Style.fontSizeS
                                    font.weight: currentTab === modelData.idx ? Font.Bold : Font.Medium
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    currentTab = modelData.idx
                                    if (modelData.idx === 1 && mainInstance) mainInstance.loadTodos()
                                }
                            }
                        }
                    }
                }
            }

            // Calendar View
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                clip: true
                visible: currentTab === 0

                Column {
                    anchors.fill: parent
                    spacing: 0

                    //Day Headers
                    Rectangle {
                        id: dayHeaders
                        width: parent.width
                        height: 56
                        color: Color.mSurfaceVariant
                        radius: Style.radiusM

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: root.timeColumnWidth
                            spacing: root.daySpacing

                            Repeater {
                                model: 7
                                Rectangle {
                                    width: mainInstance?.dayColumnWidth
                                    height: parent.height
                                    color: "transparent"
                                    property date dayDate: mainInstance?.weekDates?.[index] || new Date()
                                    property bool isToday: {
                                        var today = new Date()
                                        return dayDate.getDate() === today.getDate() &&
                                               dayDate.getMonth() === today.getMonth() &&
                                               dayDate.getFullYear() === today.getFullYear()
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        color: Color.mSurfaceVariant
                                        border.color: isToday ? Color.mPrimary : "transparent"
                                        border.width: 2
                                        radius: Style.radiusM
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            NText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: dayDate ? I18n.locale.dayName(dayDate.getDay(), Locale.ShortFormat).toUpperCase() : ""
                                                color: isToday ? Color.mPrimary : Color.mOnSurface
                                                font.pointSize: Style.fontSizeS; font.weight: Font.Medium
                                            }
                                            NText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: dayDate ? ((dayDate.getDate() < 10 ? "0" : "") + dayDate.getDate()) : ""
                                                color: isToday ? Color.mPrimary : Color.mOnSurface
                                                font.pointSize: Style.fontSizeM; font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // All-day row
                    Rectangle {
                        id: allDayEventsSection
                        width: parent.width
                        height: mainInstance ? Math.round(mainInstance.allDaySectionHeight * Style.uiScaleRatio) : 0
                        color: Color.mSurfaceVariant
                        visible: height > 0

                        Item {
                            id: allDayEventsContainer
                            anchors.fill: parent
                            anchors.leftMargin: root.timeColumnWidth

                            Repeater {
                                model: 6
                                delegate: Rectangle {
                                    width: 1; height: parent.height
                                    x: (index + 1) * ((mainInstance?.dayColumnWidth) + (root.daySpacing)) - ((root.daySpacing) / 2)
                                    color: Qt.alpha(mainInstance?.lineColor || Color.mOutline, mainInstance?.dayLineOpacitySetting || 0.9)
                                }
                            }

                            Repeater {
                                model: mainInstance?.allDayEventsWithLayout || []
                                delegate: Item {
                                    property var eventData: modelData
                                    x: eventData.startDay * ((mainInstance?.dayColumnWidth) + (root.daySpacing))
                                    y: eventData.lane * 25
                                    width: (eventData.spanDays * ((mainInstance?.dayColumnWidth) + (root.daySpacing))) - (root.daySpacing)
                                    height: 24

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Color.mTertiary
                                        radius: Style.radiusS
                                        NText {
                                            anchors.fill: parent; anchors.margins: 4
                                            text: eventData.title
                                            color: Color.mOnTertiary
                                            font.pointSize: Style.fontSizeXXS; font.weight: Font.Medium
                                            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            var tip = mainInstance?.getEventTooltip(eventData) || ""
                                            TooltipService.show(parent, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontFixed)
                                        }
                                        onClicked: mainInstance?.handleEventClick(eventData)
                                        onExited: TooltipService.hide()
                                    }
                                }
                            }
                        }
                    }
                    // Calendar flickable
                    Rectangle {
                        width: parent.width
                        height: parent.height - dayHeaders.height - (allDayEventsSection.visible ? allDayEventsSection.height : 0)
                        color: Color.mSurfaceVariant
                        radius: Style.radiusM
                        clip: true

                        Flickable {
                            id: calendarFlickable
                            anchors.fill: parent
                            clip: true
                            contentHeight: 24 * (root.hourHeight)
                            boundsBehavior: Flickable.DragOverBounds

                            Component.onCompleted: {
                                calendarFlickable.forceActiveFocus()
                            }

                            // Keyboard interaction
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                    var step = root.hourHeight
                                    var targetY = event.key === Qt.Key_Up ? Math.max(0, contentY - step) :
                                                 Math.min(Math.max(0, contentHeight - height), contentY + step)
                                    scrollAnim.targetY = targetY
                                    scrollAnim.start()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                    if (mainInstance) {
                                        mainInstance.navigateWeek(event.key === Qt.Key_Left ? -7 : 7)
                                    }
                                    event.accepted = true
                                }
                            }

                            NumberAnimation {
                                id: scrollAnim
                                target: calendarFlickable; property: "contentY"; duration: 100
                                easing.type: Easing.OutCubic; property real targetY: 0; to: targetY
                            }

                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            Row {
                                width: parent.width
                                height: parent.height

                                // Time Column
                                Column {
                                    width: root.timeColumnWidth
                                    height: parent.height
                                    Repeater {
                                        model: 23
                                        Rectangle {
                                            width: root.timeColumnWidth
                                            height: root.hourHeight
                                            color: "transparent"
                                            NText {
                                                text: {
                                                    var hour = index + 1
                                                    if (mainInstance?.use12hourFormat) {
                                                        var d = new Date(); d.setHours(hour, 0, 0, 0)
                                                        return mainInstance.formatTime(d)
                                                    }
                                                    return (hour < 10 ? "0" : "") + hour + ':00'
                                                }
                                                anchors.right: parent.right
                                                anchors.rightMargin: Style.marginS
                                                anchors.verticalCenter: parent.top
                                                anchors.verticalCenterOffset: root.hourHeight
                                                font.pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
                                            }
                                        }
                                    }
                                }

                                // Hour Rectangles
                                Item {
                                    width: 7 * ((mainInstance?.dayColumnWidth) + (root.daySpacing))
                                    height: parent.height

                                    Row {
                                        anchors.fill: parent
                                        spacing: root.daySpacing
                                        Repeater {
                                            model: 7
                                            Column {
                                                width: mainInstance?.dayColumnWidth
                                                height: parent.height
                                                Repeater {
                                                    model: 24
                                                    Rectangle { width: parent.width; height: 1; color: Color.mSurfaceVariant }
                                                }
                                            }
                                        }
                                    }
                                    // Hour Lines
                                    Repeater {
                                        model: 24
                                        Rectangle {
                                            width: parent.width; height: 1
                                            y: index * (root.hourHeight)
                                            color: Qt.alpha(mainInstance?.lineColor || Color.mOutline, mainInstance?.hourLineOpacitySetting || 0.5)
                                        }
                                    }
                                    // Day Lines
                                    Repeater {
                                        model: 6
                                        Rectangle {
                                            width: 1; height: parent.height
                                            x: (index + 1) * ((mainInstance?.dayColumnWidth) + (root.daySpacing)) - ((root.daySpacing) / 2)
                                            color: Qt.alpha(mainInstance?.lineColor || Color.mOutline, mainInstance?.dayLineOpacitySetting || 0.9)
                                        }
                                    }

                                    // Event positioning
                                    Repeater {
                                        model: mainInstance?.eventsModel
                                        delegate: Item {
                                            property var eventData: model
                                            property int dayIndex: mainInstance?.getDisplayDayIndexForDate(model.startTime) ?? -1
                                            property real startHour: model.startTime.getHours() + model.startTime.getMinutes() / 60
                                            property real endHour: model.endTime.getHours() + model.endTime.getMinutes() / 60
                                            property real duration: Math.max(0, (model.endTime - model.startTime) / 3600000)

                                            property real exactHeight: Math.max(1, duration * (mainInstance?.hourHeight || 50) - 1)
                                            property bool isCompact: exactHeight < 40
                                            property var overlapInfo: mainInstance?.overlappingEventsData?.[index] ?? {
                                                xOffset: 0, width: (mainInstance?.dayColumnWidth) - 8, lane: 0, totalLanes: 1
                                            }
                                            property real eventWidth: overlapInfo.width - 1
                                            property real eventXOffset: overlapInfo.xOffset

                                            visible: dayIndex >= 0 && dayIndex < 7 && duration > 0
                                            width: eventWidth
                                            height: exactHeight
                                            x: dayIndex * ((mainInstance?.dayColumnWidth) + (root.daySpacing)) + eventXOffset
                                            y: startHour * (mainInstance?.hourHeight || 50)
                                            z: 100 + overlapInfo.lane

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Color.mPrimary
                                                radius: Style.radiusS
                                                opacity: 0.9
                                                clip: true
                                                Rectangle {
                                                    visible: exactHeight < 5 && overlapInfo.lane > 0
                                                    anchors.fill: parent
                                                    color: "transparent"
                                                    radius: parent.radius
                                                    border.width: 1
                                                    border.color: Color.mPrimary
                                                }
                                                Loader {
                                                    anchors.fill: parent
                                                    anchors.margins: exactHeight < 10 ? 1 : Style.marginS
                                                    anchors.leftMargin: exactHeight < 10 ? 1 : Style.marginS + 3
                                                    sourceComponent: isCompact ? compactLayout : normalLayout
                                                }
                                            }

                                            Component {
                                                id: normalLayout
                                                Column {
                                                    spacing: 2
                                                    width: parent.width - 3
                                                    NText {
                                                        visible: exactHeight >= 20
                                                        text: model.title
                                                        color: Color.mOnPrimary
                                                        font.pointSize: Style.fontSizeXS; font.weight: Font.Medium
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                    NText {
                                                        visible: exactHeight >= 30
                                                        text: mainInstance?.formatTimeRangeForDisplay(model) || ""
                                                        color: Color.mOnPrimary
                                                        font.pointSize: Style.fontSizeXXS; opacity: 0.9
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                    NText {
                                                        visible: exactHeight >= 45 && model.location && model.location !== ""
                                                        text: "\u26B2 " + (model.location || "")
                                                        color: Color.mOnPrimary
                                                        font.pointSize: Style.fontSizeXXS; opacity: 0.8
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                }
                                            }

                                            Component {
                                                id: compactLayout
                                                NText {
                                                    text: exactHeight < 15 ? model.title :
                                                          model.title + " • " + (mainInstance?.formatTimeRangeForDisplay(model) || "")
                                                    color: Color.mOnPrimary
                                                    font.pointSize: exactHeight < 15 ? Style.fontSizeXXS : Style.fontSizeXS
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                                    width: parent.width - 3
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    var tip = mainInstance?.getEventTooltip(model) || ""
                                                    TooltipService.show(parent, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontFixed)
                                                }
                                                onClicked: mainInstance?.handleEventClick(eventData)
                                                onExited: TooltipService.hide()
                                            }
                                        }
                                    }

                                    // Time Indicator
                                    Rectangle {
                                        property var now: new Date()
                                        property date today: new Date(now.getFullYear(), now.getMonth(), now.getDate())
                                        property date weekStartDate: mainInstance?.weekStart ?? new Date()
                                        property date weekEndDate: mainInstance ?
                                            new Date(mainInstance.weekStart.getFullYear(), mainInstance.weekStart.getMonth(), mainInstance.weekStart.getDate() + 7) : new Date()
                                        property bool inCurrentWeek: today >= weekStartDate && today < weekEndDate
                                        property int currentDay: mainInstance?.getDayIndexForDate(now) ?? -1
                                        property real currentHour: now.getHours() + now.getMinutes() / 60

                                        visible: inCurrentWeek && currentDay >= 0
                                        width: mainInstance?.dayColumnWidth
                                        height: 2
                                        x: currentDay * ((mainInstance?.dayColumnWidth) + (root.daySpacing))
                                        y: currentHour * (root.hourHeight)
                                        color: Color.mError
                                        radius: 1
                                        z: 1000
                                        Rectangle {
                                            width: 8; height: 8; radius: 4; color: Color.mError
                                            anchors.verticalCenter: parent.verticalCenter; x: -4
                                        }
                                        Timer {
                                            interval: 60000; running: true; repeat: true
                                            onTriggered: parent.now = new Date()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Tasks View
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                clip: true
                visible: currentTab === 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Empty state
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: mainInstance?.todosModel.count === 0 && !mainInstance?.todosLoading

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Style.marginM
                            NIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "clipboard-check"
                                pointSize: Style.fontSizeXXL * 2
                                color: Color.mOnSurfaceVariant
                                opacity: 0.4
                            }
                            NText {
                                Layout.alignment: Qt.AlignHCenter
                                text: pluginApi.tr("panel.no_tasks")
                                color: Color.mOnSurfaceVariant
                                font.pointSize: Style.fontSizeM
                            }
                        }
                    }

                    // Task list
                    ListView {
                        id: todosListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: mainInstance?.todosModel
                        clip: true
                        visible: mainInstance?.todosModel.count > 0 || mainInstance?.todosLoading
                        spacing: 1

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            width: todosListView.width
                            height: todoRow.implicitHeight + 2 * Style.marginS
                            color: todoMouseArea.containsMouse ? Qt.alpha(Color.mSurface, 0.5) : "transparent"

                            RowLayout {
                                id: todoRow
                                anchors.fill: parent
                                anchors.margins: Style.marginS
                                anchors.leftMargin: Style.marginM
                                anchors.rightMargin: Style.marginM
                                spacing: Style.marginS

                                // Priority indicator
                                Rectangle {
                                    Layout.preferredWidth: 4
                                    Layout.fillHeight: true
                                    Layout.topMargin: 2
                                    Layout.bottomMargin: 2
                                    radius: 2
                                    color: root.priorityColor(model.priority)
                                }

                                // Checkbox
                                Rectangle {
                                    Layout.preferredWidth: 22; Layout.preferredHeight: 22
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 4
                                    color: model.status === "COMPLETED" ? Color.mPrimary : "transparent"
                                    border.width: 2
                                    border.color: model.status === "COMPLETED" ? Color.mPrimary : Color.mOnSurfaceVariant

                                    NIcon {
                                        anchors.centerIn: parent
                                        icon: "check"
                                        pointSize: Style.fontSizeXS
                                        color: Color.mOnPrimary
                                        visible: model.status === "COMPLETED"
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (model.status === "COMPLETED")
                                                mainInstance?.uncompleteTodo(model.calendarUid, model.uid)
                                            else
                                                mainInstance?.completeTodo(model.calendarUid, model.uid)
                                        }
                                    }
                                }

                                // Task content
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    NText {
                                        Layout.fillWidth: true
                                        text: model.summary
                                        color: model.status === "COMPLETED" ? Color.mOnSurfaceVariant : Color.mOnSurface
                                        font.pointSize: Style.fontSizeS
                                        font.strikeout: model.status === "COMPLETED"
                                        elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        spacing: Style.marginS
                                        visible: model.due !== "" && model.due !== undefined && model.due !== null
                                        NIcon {
                                            icon: "clock"
                                            pointSize: Style.fontSizeXXS
                                            color: root.isTodoOverdue(model.due, model.status) ? Color.mError : Color.mOnSurfaceVariant
                                        }
                                        NText {
                                            text: root.formatTodoDueDate(model.due)
                                            font.pointSize: Style.fontSizeXXS
                                            color: root.isTodoOverdue(model.due, model.status) ? Color.mError : Color.mOnSurfaceVariant
                                        }
                                        NText {
                                            text: model.calendarName
                                            font.pointSize: Style.fontSizeXXS
                                            color: Color.mOnSurfaceVariant
                                            opacity: 0.7
                                        }
                                    }
                                }

                                // Delete button
                                NIconButton {
                                    icon: "x"
                                    tooltipText: I18n.tr("common.delete") || "Delete"
                                    visible: todoMouseArea.containsMouse
                                    onClicked: mainInstance?.deleteTodo(model.calendarUid, model.uid)
                                }
                            }

                            MouseArea {
                                id: todoMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }
            }
        }
    }
}
