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
    property real contentPreferredHeight: 900 * Style.uiScaleRatio
    property real topHeaderHeight: 60 * Style.uiScaleRatio
    readonly property bool allowAttach: mainInstance ? mainInstance.panelModeSetting === "attached" : false
    readonly property bool panelAnchorHorizontalCenter: mainInstance ? mainInstance.panelModeSetting === "centered" : false
    readonly property bool panelAnchorVerticalCenter: mainInstance ? mainInstance.panelModeSetting === "centered" : false
    anchors.fill: parent

    property bool showCreateDialog: false
    property bool showCreateTaskDialog: false
    property bool showEventDetailDialog: false
    property bool eventDetailEditMode: false
    property bool showDeleteConfirmation: false
    property bool showTodoDetailDialog: false
    property bool todoDetailEditMode: false
    property bool showTodoDeleteConfirmation: false

    property real defaultHourHeight: 50 * Style.uiScaleRatio
    property real minHourHeight: 32 * Style.uiScaleRatio
    property real hourHeight: defaultHourHeight
    property real timeColumnWidth: 65 * Style.uiScaleRatio
    property real daySpacing: 1 * Style.uiScaleRatio

    // Panel doesn't need its own CalendarService connection - Main.qml handles it.
    // When panel opens, trigger a fresh load if needed.
    Component.onCompleted: {
        mainInstance?.initializePlugin()
        Qt.callLater(root.adjustHourHeightForViewport)
    }
    onVisibleChanged: if (visible && mainInstance) {
        mainInstance.refreshView()
        mainInstance.goToToday()
        Qt.callLater(root.scrollToCurrentTime)
        mainInstance.loadTodos()
        Qt.callLater(root.adjustHourHeightForViewport)
    }

    function adjustHourHeightForViewport() {
        if (!calendarFlickable || calendarFlickable.height <= 0) return
        // Target showing 08:30–24:00 (~15.5 hours) without scroll; fall back to min height if space is tight.
        var target = calendarFlickable.height / 15.5
        var newHeight = Math.max(minHourHeight, Math.min(defaultHourHeight, target))
        if (Math.abs(newHeight - hourHeight) > 0.5) hourHeight = newHeight
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
                    placeholderText: "YYYY-MM-DD"
                    color: Color.mOnSurface
                    background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                }

                // Use end_time label to reflect deadline semantics
                NText { text: pluginApi.tr("panel.end_time"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                TextField {
                    id: createTaskDueTime
                    Layout.fillWidth: true
                    placeholderText: "HH:MM"
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
                                    var dateParts = createTaskDueDate.text.split("-")
                                    var timeParts = createTaskDueTime.text.split(":")
                                    var h = createTaskDueTime.text.trim() === "" ? 0 : parseInt(timeParts[0])
                                    var m = createTaskDueTime.text.trim() === "" ? 0 : parseInt(timeParts[1] || "0")
                                    var d = new Date(parseInt(dateParts[0]), parseInt(dateParts[1]) - 1, parseInt(dateParts[2]), h, m, 0)
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

    // Event detail/edit popup
    Rectangle {
        id: eventDetailOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: showEventDetailDialog
        z: 2000

        MouseArea { anchors.fill: parent; onClicked: { showEventDetailDialog = false; eventDetailEditMode = false; showDeleteConfirmation = false } }

        Rectangle {
            anchors.centerIn: parent
            width: 420 * Style.uiScaleRatio
            height: eventDetailColumn.implicitHeight + 2 * Style.marginM
            color: Color.mSurface
            radius: Style.radiusM

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: eventDetailColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                property var evt: mainInstance?.selectedEvent || {}

                // View mode
                ColumnLayout {
                    visible: !eventDetailEditMode && !showDeleteConfirmation
                    spacing: Style.marginS
                    Layout.fillWidth: true

                    NText {
                        text: eventDetailColumn.evt.title || ""
                        font.pointSize: Style.fontSizeL; font.weight: Font.Bold
                        color: Color.mOnSurface
                        wrapMode: Text.Wrap; Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: Style.marginS
                        NIcon { icon: "clock"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                        NText {
                            text: {
                                var e = eventDetailColumn.evt
                                if (!e.startTime) return ""
                                return mainInstance?.formatDateTime(e.startTime) + " - " + mainInstance?.formatDateTime(e.endTime)
                            }
                            font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                            wrapMode: Text.Wrap; Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        visible: (eventDetailColumn.evt.location || "") !== ""
                        spacing: Style.marginS
                        NIcon { icon: "map-pin"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                        NText {
                            text: eventDetailColumn.evt.location || ""
                            font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                            wrapMode: Text.Wrap; Layout.fillWidth: true
                        }
                    }

                    NText {
                        visible: (eventDetailColumn.evt.description || "") !== ""
                        text: eventDetailColumn.evt.description || ""
                        font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                        wrapMode: Text.Wrap; Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: editEventBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: editEventBtn.implicitHeight + Style.marginS
                            color: Color.mPrimary; radius: Style.radiusS
                            visible: (eventDetailColumn.evt.eventUid || "") !== ""
                            NText {
                                id: editEventBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.edit") || "Edit"
                                color: Color.mOnPrimary; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var e = eventDetailColumn.evt
                                    editEventSummary.text = e.title || ""
                                    editEventLocation.text = e.location || ""
                                    editEventDescription.text = e.description || ""
                                    if (e.startTime) {
                                        var s = new Date(e.startTime)
                                        editEventDate.text = s.getFullYear() + "-" + String(s.getMonth()+1).padStart(2,'0') + "-" + String(s.getDate()).padStart(2,'0')
                                        editEventStartTime.text = String(s.getHours()).padStart(2,'0') + ":" + String(s.getMinutes()).padStart(2,'0')
                                    }
                                    if (e.endTime) {
                                        var en = new Date(e.endTime)
                                        editEventEndTime.text = String(en.getHours()).padStart(2,'0') + ":" + String(en.getMinutes()).padStart(2,'0')
                                    }
                                    eventDetailEditMode = true
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: deleteEventBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: deleteEventBtn.implicitHeight + Style.marginS
                            color: Color.mError; radius: Style.radiusS
                            visible: (eventDetailColumn.evt.eventUid || "") !== ""
                            NText {
                                id: deleteEventBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.delete") || "Delete"
                                color: Color.mOnError; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: showDeleteConfirmation = true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: closeEventBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: closeEventBtn.implicitHeight + Style.marginS
                            color: Color.mSurfaceVariant; radius: Style.radiusS
                            NText {
                                id: closeEventBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.close") || "Close"
                                color: Color.mOnSurfaceVariant
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { showEventDetailDialog = false; eventDetailEditMode = false }
                            }
                        }
                    }
                }

                // Delete confirmation mode
                ColumnLayout {
                    visible: showDeleteConfirmation
                    spacing: Style.marginS
                    Layout.fillWidth: true

                    NText {
                        text: (pluginApi.tr("panel.delete_confirm") || "Delete this event?")
                        font.pointSize: Style.fontSizeM; font.weight: Font.Bold
                        color: Color.mOnSurface
                    }
                    NText {
                        text: eventDetailColumn.evt.title || ""
                        font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: confirmDeleteBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: confirmDeleteBtn.implicitHeight + Style.marginS
                            color: Color.mError; radius: Style.radiusS
                            NText {
                                id: confirmDeleteBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.delete") || "Delete"
                                color: Color.mOnError; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var e = eventDetailColumn.evt
                                    mainInstance?.deleteEvent(e.calendarUid, e.eventUid)
                                    showEventDetailDialog = false
                                    showDeleteConfirmation = false
                                    eventDetailEditMode = false
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: cancelDeleteBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: cancelDeleteBtn.implicitHeight + Style.marginS
                            color: Color.mSurfaceVariant; radius: Style.radiusS
                            NText {
                                id: cancelDeleteBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.cancel"); color: Color.mOnSurfaceVariant
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: showDeleteConfirmation = false
                            }
                        }
                    }
                }

                // Edit mode
                ColumnLayout {
                    visible: eventDetailEditMode && !showDeleteConfirmation
                    spacing: Style.marginS
                    Layout.fillWidth: true

                    NText {
                        text: pluginApi.tr("panel.edit_event") || "Edit Event"
                        font.pointSize: Style.fontSizeL; font.weight: Font.Bold
                        color: Color.mOnSurface
                    }

                    NText { text: pluginApi.tr("panel.summary"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editEventSummary
                        Layout.fillWidth: true
                        color: Color.mOnSurface
                        background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                    }

                    NText { text: pluginApi.tr("panel.date"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editEventDate
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
                                id: editEventStartTime
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
                                id: editEventEndTime
                                Layout.fillWidth: true
                                placeholderText: "HH:MM"
                                color: Color.mOnSurface
                                background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                            }
                        }
                    }

                    NText { text: pluginApi.tr("panel.location"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editEventLocation
                        Layout.fillWidth: true
                        color: Color.mOnSurface
                        background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                    }

                    NText { text: pluginApi.tr("panel.description"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editEventDescription
                        Layout.fillWidth: true
                        color: Color.mOnSurface
                        background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: saveEventBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: saveEventBtn.implicitHeight + Style.marginS
                            color: Color.mPrimary; radius: Style.radiusS
                            NText {
                                id: saveEventBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.save") || "Save"
                                color: Color.mOnPrimary; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var e = eventDetailColumn.evt
                                    var dateParts = editEventDate.text.split("-")
                                    var startParts = editEventStartTime.text.split(":")
                                    var endParts = editEventEndTime.text.split(":")
                                    var startDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1])-1, parseInt(dateParts[2]),
                                                             parseInt(startParts[0]), parseInt(startParts[1]), 0)
                                    var endDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1])-1, parseInt(dateParts[2]),
                                                           parseInt(endParts[0]), parseInt(endParts[1]), 0)
                                    mainInstance?.updateEvent(
                                        e.calendarUid, e.eventUid,
                                        editEventSummary.text.trim(),
                                        editEventLocation.text.trim(),
                                        editEventDescription.text.trim(),
                                        Math.floor(startDate.getTime()/1000),
                                        Math.floor(endDate.getTime()/1000))
                                    showEventDetailDialog = false
                                    eventDetailEditMode = false
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: editCancelBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: editCancelBtn.implicitHeight + Style.marginS
                            color: Color.mSurfaceVariant; radius: Style.radiusS
                            NText {
                                id: editCancelBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.cancel"); color: Color.mOnSurfaceVariant
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: eventDetailEditMode = false
                            }
                        }
                    }
                }
            }
        }
    }

    // Todo detail/edit popup
    Rectangle {
        id: todoDetailOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: showTodoDetailDialog
        z: 2000

        MouseArea { anchors.fill: parent; onClicked: { showTodoDetailDialog = false; todoDetailEditMode = false; showTodoDeleteConfirmation = false } }

        Rectangle {
            anchors.centerIn: parent
            width: 420 * Style.uiScaleRatio
            height: todoDetailColumn.implicitHeight + 2 * Style.marginM
            color: Color.mSurface
            radius: Style.radiusM

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: todoDetailColumn
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                property var todo: mainInstance?.selectedTodo || {}

                // View mode
                ColumnLayout {
                    visible: !todoDetailEditMode && !showTodoDeleteConfirmation
                    spacing: Style.marginS
                    Layout.fillWidth: true

                    NText {
                        text: (todoDetailColumn.todo.status === "COMPLETED" ? "\u2611 " : "\u2610 ") + (todoDetailColumn.todo.summary || "")
                        font.pointSize: Style.fontSizeL; font.weight: Font.Bold
                        color: Color.mOnSurface
                        wrapMode: Text.Wrap; Layout.fillWidth: true
                    }

                    RowLayout {
                        visible: todoDetailColumn.todo.due != null
                        spacing: Style.marginS
                        NIcon { icon: "clock"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                        NText {
                            text: todoDetailColumn.todo.due ? mainInstance?.formatDateTime(new Date(todoDetailColumn.todo.due)) || "" : ""
                            font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                        }
                    }

                    RowLayout {
                        visible: (todoDetailColumn.todo.priority || 0) > 0
                        spacing: Style.marginS
                        NIcon { icon: "flag"; pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }
                        NText {
                            text: {
                                var p = todoDetailColumn.todo.priority || 0
                                return p <= 4 ? (pluginApi.tr("panel.priority") + ": " + pluginApi.tr("panel.priority_high")) :
                                       p <= 6 ? (pluginApi.tr("panel.priority") + ": " + pluginApi.tr("panel.priority_medium")) :
                                                (pluginApi.tr("panel.priority") + ": " + pluginApi.tr("panel.priority_low"))
                            }
                            font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                        }
                    }

                    NText {
                        visible: (todoDetailColumn.todo.description || "") !== ""
                        text: todoDetailColumn.todo.description || ""
                        font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                        wrapMode: Text.Wrap; Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        // Toggle complete button
                        Rectangle {
                            Layout.preferredWidth: toggleTodoBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: toggleTodoBtn.implicitHeight + Style.marginS
                            color: Color.mSecondary; radius: Style.radiusS
                            NText {
                                id: toggleTodoBtn; anchors.centerIn: parent
                                text: todoDetailColumn.todo.status === "COMPLETED" ? "\u2610" : "\u2611"
                                color: Color.mOnSecondary; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var t = todoDetailColumn.todo
                                    if (t.status === "COMPLETED")
                                        mainInstance?.uncompleteTodo(t.calendarUid, t.todoUid)
                                    else
                                        mainInstance?.completeTodo(t.calendarUid, t.todoUid)
                                    showTodoDetailDialog = false
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: editTodoBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: editTodoBtn.implicitHeight + Style.marginS
                            color: Color.mPrimary; radius: Style.radiusS
                            NText {
                                id: editTodoBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.edit"); color: Color.mOnPrimary; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var t = todoDetailColumn.todo
                                    editTodoSummary.text = t.summary || ""
                                    editTodoDescription.text = t.description || ""
                                    if (t.due) {
                                        var d = new Date(t.due)
                                        editTodoDueDate.text = d.getFullYear() + "-" + String(d.getMonth()+1).padStart(2,'0') + "-" + String(d.getDate()).padStart(2,'0')
                                        editTodoDueTime.text = String(d.getHours()).padStart(2,'0') + ":" + String(d.getMinutes()).padStart(2,'0')
                                    } else {
                                        editTodoDueDate.text = ""
                                        editTodoDueTime.text = ""
                                    }
                                    editTodoPriority = t.priority || 0
                                    todoDetailEditMode = true
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: deleteTodoBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: deleteTodoBtn.implicitHeight + Style.marginS
                            color: Color.mError; radius: Style.radiusS
                            NText {
                                id: deleteTodoBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.delete"); color: Color.mOnError; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: showTodoDeleteConfirmation = true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: closeTodoBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: closeTodoBtn.implicitHeight + Style.marginS
                            color: Color.mSurfaceVariant; radius: Style.radiusS
                            NText {
                                id: closeTodoBtn; anchors.centerIn: parent
                                text: pluginApi.tr("panel.close"); color: Color.mOnSurfaceVariant
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { showTodoDetailDialog = false; todoDetailEditMode = false }
                            }
                        }
                    }
                }

                // Delete confirmation
                ColumnLayout {
                    visible: showTodoDeleteConfirmation
                    spacing: Style.marginS
                    Layout.fillWidth: true

                    NText {
                        text: pluginApi.tr("panel.delete_task_confirm")
                        font.pointSize: Style.fontSizeM; font.weight: Font.Bold; color: Color.mOnSurface
                    }
                    NText { text: todoDetailColumn.todo.summary || ""; font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant }

                    RowLayout {
                        Layout.fillWidth: true; spacing: Style.marginS
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: confirmDeleteTodoBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: confirmDeleteTodoBtn.implicitHeight + Style.marginS
                            color: Color.mError; radius: Style.radiusS
                            NText { id: confirmDeleteTodoBtn; anchors.centerIn: parent; text: pluginApi.tr("panel.delete"); color: Color.mOnError; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var t = todoDetailColumn.todo
                                    mainInstance?.deleteTodo(t.calendarUid, t.todoUid)
                                    showTodoDetailDialog = false; showTodoDeleteConfirmation = false; todoDetailEditMode = false
                                }
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: cancelDeleteTodoBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: cancelDeleteTodoBtn.implicitHeight + Style.marginS
                            color: Color.mSurfaceVariant; radius: Style.radiusS
                            NText { id: cancelDeleteTodoBtn; anchors.centerIn: parent; text: pluginApi.tr("panel.cancel"); color: Color.mOnSurfaceVariant }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showTodoDeleteConfirmation = false }
                        }
                    }
                }

                // Edit mode
                property int editTodoPriority: 0
                ColumnLayout {
                    visible: todoDetailEditMode && !showTodoDeleteConfirmation
                    spacing: Style.marginS
                    Layout.fillWidth: true

                    NText { text: pluginApi.tr("panel.edit_task"); font.pointSize: Style.fontSizeL; font.weight: Font.Bold; color: Color.mOnSurface }

                    NText { text: pluginApi.tr("panel.task_summary"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editTodoSummary; Layout.fillWidth: true; color: Color.mOnSurface
                        background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                    }

                    NText { text: pluginApi.tr("panel.due_date"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editTodoDueDate; Layout.fillWidth: true; placeholderText: "YYYY-MM-DD"; color: Color.mOnSurface
                        background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                    }

                    NText { text: pluginApi.tr("panel.end_time"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editTodoDueTime; Layout.fillWidth: true; placeholderText: "HH:MM"; color: Color.mOnSurface
                        background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                    }

                    NText { text: pluginApi.tr("panel.description"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    TextField {
                        id: editTodoDescription; Layout.fillWidth: true; color: Color.mOnSurface
                        background: Rectangle { color: Color.mSurfaceVariant; radius: Style.radiusS }
                    }

                    NText { text: pluginApi.tr("panel.priority"); color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeS }
                    RowLayout {
                        spacing: Style.marginS
                        Repeater {
                            model: [
                                { label: pluginApi.tr("panel.priority_high"), value: 1 },
                                { label: pluginApi.tr("panel.priority_medium"), value: 5 },
                                { label: pluginApi.tr("panel.priority_low"), value: 9 }
                            ]
                            Rectangle {
                                Layout.preferredWidth: editPriLabel.implicitWidth + 2 * Style.marginM
                                Layout.preferredHeight: editPriLabel.implicitHeight + Style.marginS
                                color: todoDetailColumn.editTodoPriority === modelData.value ? Color.mPrimary : Color.mSurfaceVariant
                                radius: Style.radiusS
                                NText {
                                    id: editPriLabel; anchors.centerIn: parent
                                    text: modelData.label
                                    color: todoDetailColumn.editTodoPriority === modelData.value ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                    font.weight: Font.Medium
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: todoDetailColumn.editTodoPriority =
                                        todoDetailColumn.editTodoPriority === modelData.value ? 0 : modelData.value
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: Style.marginS
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: saveTodoBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: saveTodoBtn.implicitHeight + Style.marginS
                            color: Color.mPrimary; radius: Style.radiusS
                            NText { id: saveTodoBtn; anchors.centerIn: parent; text: pluginApi.tr("panel.save"); color: Color.mOnPrimary; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var t = todoDetailColumn.todo
                                    var dueTs = 0
                                    if (editTodoDueDate.text.trim() !== "") {
                                        var dateParts = editTodoDueDate.text.split("-")
                                        var timeParts = editTodoDueTime.text.split(":")
                                        var h = editTodoDueTime.text.trim() === "" ? 0 : parseInt(timeParts[0])
                                        var m = editTodoDueTime.text.trim() === "" ? 0 : parseInt(timeParts[1] || "0")
                                        var d = new Date(parseInt(dateParts[0]), parseInt(dateParts[1]) - 1, parseInt(dateParts[2]), h, m, 0)
                                        if (!isNaN(d.getTime())) dueTs = Math.floor(d.getTime() / 1000)
                                    }
                                    mainInstance?.updateTodoFields(
                                        t.calendarUid, t.todoUid,
                                        editTodoSummary.text.trim(),
                                        editTodoDescription.text.trim(),
                                        dueTs, todoDetailColumn.editTodoPriority)
                                    showTodoDetailDialog = false; todoDetailEditMode = false
                                }
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: editTodoCancelBtn.implicitWidth + 2 * Style.marginM
                            Layout.preferredHeight: editTodoCancelBtn.implicitHeight + Style.marginS
                            color: Color.mSurfaceVariant; radius: Style.radiusS
                            NText { id: editTodoCancelBtn; anchors.centerIn: parent; text: pluginApi.tr("panel.cancel"); color: Color.mOnSurfaceVariant }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: todoDetailEditMode = false }
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

                    NIcon { icon: "calendar-week"; pointSize: Style.fontSizeXXL; color: Color.mPrimary }

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
                                text: mainInstance?.monthRangeText || ""
                                font.pointSize: Style.fontSizeS; font.weight: Font.Medium; color: Color.mOnSurfaceVariant
                            }
                            Rectangle {
                                Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                color: mainInstance?.isLoading ? Color.mError :
                                       mainInstance?.syncStatus?.includes("No") ? Color.mError : Color.mOnSurfaceVariant
                            }
                            NText {
                                text: mainInstance?.syncStatus || ""
                                font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: Style.marginS
                        NIconButton {
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
                            icon: "clipboard-check"; tooltipText: pluginApi.tr("panel.add_task")
                            onClicked: {
                                createTaskSummary.text = ""
                                var now = new Date()
                                var startH = now.getHours() + 1
                                createTaskDueDate.text = now.getFullYear() + "-" + String(now.getMonth()+1).padStart(2,'0') + "-" + String(now.getDate()).padStart(2,'0')
                                createTaskDueTime.text = String(startH).padStart(2,'0') + ":00"
                                createTaskDescription.text = ""
                                createTaskDialogColumn.selectedPriority = 0
                                showCreateTaskDialog = true
                            }
                        }
                        NIconButton {
                            icon: mainInstance?.showCompletedTodos ? "eye-off" : "eye"
                            tooltipText: pluginApi.tr("panel.show_completed")
                            onClicked: {
                                if (mainInstance) {
                                    mainInstance.showCompletedTodos = !mainInstance.showCompletedTodos
                                    mainInstance.loadTodos()
                                }
                            }
                        }
                        NIconButton {
                            icon: "chevron-left"
                            onClicked: mainInstance?.navigateWeek(-7)
                        }
                        NIconButton {
                            icon: "calendar"; tooltipText: pluginApi.tr("panel.today")
                            onClicked: { mainInstance?.goToToday(); Qt.callLater(root.scrollToCurrentTime) }
                        }
                        NIconButton {
                            icon: "chevron-right"
                            onClicked: mainInstance?.navigateWeek(7)
                        }
                        NIconButton {
                            icon: "refresh"; tooltipText: I18n.tr("common.refresh")
                            onClicked: { mainInstance?.loadEvents(); mainInstance?.loadTodos() }
                            enabled: mainInstance ? !mainInstance.isLoading : false
                        }
                        NIconButton {
                            icon: "close"; tooltipText: I18n.tr("common.close")
                            onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
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
                                    property bool isTodoItem: eventData.isTodo || false
                                    property bool isDeadline: eventData.isDeadlineMarker || false
                                    x: eventData.startDay * ((mainInstance?.dayColumnWidth) + (root.daySpacing))
                                    y: eventData.lane * 25
                                    width: (eventData.spanDays * ((mainInstance?.dayColumnWidth) + (root.daySpacing))) - (root.daySpacing)
                                    height: isDeadline ? 10 : 24

                                    Rectangle {
                                        anchors.fill: parent
                                        color: isDeadline ? Color.mSecondary : (isTodoItem ? Color.mSecondary : Color.mTertiary)
                                        radius: Style.radiusS
                                        opacity: isTodoItem && eventData.todoStatus === "COMPLETED" ? 0.5 : 1.0
                                        NText {
                                            anchors.fill: parent; anchors.margins: 4
                                            text: isDeadline ? "" : (isTodoItem ? (eventData.todoStatus === "COMPLETED" ? "\u2611 " : "\u2610 ") : "") + eventData.title
                                            color: isDeadline ? Color.mOnSecondary : (isTodoItem ? Color.mOnSecondary : Color.mOnTertiary)
                                            font.pointSize: Style.fontSizeXXS; font.weight: Font.Medium
                                            font.strikeout: isTodoItem && eventData.todoStatus === "COMPLETED"
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
                                        onClicked: {
                                            if (isTodoItem) {
                                                mainInstance?.handleTodoClick(eventData)
                                                showTodoDetailDialog = true
                                                todoDetailEditMode = false
                                                showTodoDeleteConfirmation = false
                                            } else {
                                                mainInstance?.handleEventClick(eventData)
                                                showEventDetailDialog = true
                                                eventDetailEditMode = false
                                                showDeleteConfirmation = false
                                            }
                                        }
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
                            onHeightChanged: Qt.callLater(root.adjustHourHeightForViewport)

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

                                            property real exactHeight: Math.max(1, duration * (root.hourHeight) - 1)
                                            property real minEventHeight: (isTodoItem ? 22 : 18) * Style.uiScaleRatio
                                            property real renderHeight: isDeadline
                                                ? Math.max(8, Math.min(12, exactHeight))
                                                : Math.max(exactHeight, minEventHeight)
                                            property bool isCompact: renderHeight < 40
                                            property var overlapInfo: mainInstance?.overlappingEventsData?.[index] ?? {
                                                xOffset: 0, width: (mainInstance?.dayColumnWidth) - 8, lane: 0, totalLanes: 1
                                            }
                                            property real eventWidth: overlapInfo.width - 1
                                            property real eventXOffset: overlapInfo.xOffset

                                            property bool isTodoItem: model.isTodo || false
                                            property bool isDeadline: (!isTodoItem) && (model.isDeadlineMarker || false)
                                            property color eventColor: isDeadline ? Color.mSecondary : (isTodoItem ? Color.mSecondary : Color.mPrimary)
                                            property color eventTextColor: isDeadline ? Color.mOnSecondary : (isTodoItem ? Color.mOnSecondary : Color.mOnPrimary)

                                            visible: dayIndex >= 0 && dayIndex < 7 && duration > 0
                                            width: eventWidth
                                            height: renderHeight
                                            x: dayIndex * ((mainInstance?.dayColumnWidth) + (root.daySpacing)) + eventXOffset
                                            y: startHour * (root.hourHeight)
                                            z: 100 + overlapInfo.lane

                                            Rectangle {
                                                anchors.fill: parent
                                                color: eventColor
                                                radius: Style.radiusS
                                                opacity: isDeadline ? 0.95 : (isTodoItem && model.todoStatus === "COMPLETED" ? 0.5 : 0.9)
                                                clip: true
                                                Rectangle {
                                                    visible: exactHeight < 5 && overlapInfo.lane > 0
                                                    anchors.fill: parent
                                                    color: "transparent"
                                                    radius: parent.radius
                                                    border.width: 1
                                                    border.color: eventColor
                                                }
                                                Loader {
                                                    anchors.fill: parent
                                                    anchors.margins: renderHeight < 12 ? 1 : Style.marginS
                                                    anchors.leftMargin: renderHeight < 12 ? 1 : Style.marginS + 3
                                                    sourceComponent: isDeadline ? deadlineLayout : (isCompact ? compactLayout : normalLayout)
                                                }
                                            }

                                            Component {
                                                id: normalLayout
                                                Column {
                                                    spacing: 2
                                                    width: parent.width - 3
                                                    NText {
                                                        visible: renderHeight >= 20
                                                        text: (isTodoItem ? (model.todoStatus === "COMPLETED" ? "\u2611 " : "\u2610 ") : "") + model.title
                                                        color: eventTextColor
                                                        font.pointSize: Style.fontSizeXS; font.weight: Font.Medium
                                                        font.strikeout: isTodoItem && model.todoStatus === "COMPLETED"
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                    NText {
                                                        visible: renderHeight >= 30 && !isTodoItem
                                                        text: mainInstance?.formatTimeRangeForDisplay(model) || ""
                                                        color: eventTextColor
                                                        font.pointSize: Style.fontSizeXXS; opacity: 0.9
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                    NText {
                                                        visible: renderHeight >= 45 && model.location && model.location !== ""
                                                        text: "\u26B2 " + (model.location || "")
                                                        color: eventTextColor
                                                        font.pointSize: Style.fontSizeXXS; opacity: 0.8
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                }
                                            }

                                            Component {
                                                id: compactLayout
                                                NText {
                                                    text: {
                                                        var prefix = isTodoItem ? (model.todoStatus === "COMPLETED" ? "\u2611 " : "\u2610 ") : ""
                                                        if (renderHeight < 15) return prefix + model.title
                                                        if (isTodoItem) return prefix + model.title
                                                        return model.title + " \u2022 " + (mainInstance?.formatTimeRangeForDisplay(model) || "")
                                                    }
                                                    color: eventTextColor
                                                    font.pointSize: renderHeight < 15 ? Style.fontSizeXXS : Style.fontSizeXS
                                                    font.weight: Font.Medium
                                                    font.strikeout: isTodoItem && model.todoStatus === "COMPLETED"
                                                    elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                                    width: parent.width - 3
                                                }
                                            }

                                            Component {
                                                id: deadlineLayout
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: eventColor
                                                    radius: parent.radius
                                                    opacity: 0.95
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
                                                onClicked: {
                                                    if (isTodoItem) {
                                                        mainInstance?.handleTodoClick(model)
                                                        showTodoDetailDialog = true
                                                        todoDetailEditMode = false
                                                        showTodoDeleteConfirmation = false
                                                    } else {
                                                        mainInstance?.handleEventClick(eventData)
                                                        showEventDetailDialog = true
                                                        eventDetailEditMode = false
                                                        showDeleteConfirmation = false
                                                    }
                                                }
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

        }
    }
}
