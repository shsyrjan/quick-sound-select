import MuseScore 3.0
import QtQuick 2.1
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

MuseScore {
    menuPath: "Plugins.QuickSoundSelect"
    version:  "1.0.0"
    description: "Map parts to new sounds quickly."
    pluginType: "dialog"

    id: mainWindow
    width: 400
    height: 500

    property var defaultMappings: [
        {
            name: "All -> Piano",
            rules: [
                {
                    name: "Piano",
                    propertyPatterns: [
                        { property: "instrumentId", pattern: ".*" },
                        { property: "instrumentId", pattern: "^(?!drum)" },
                    ],
                    modifiers: [
                        { property: "midiBank", value: 0 },
                        { property: "midiProgram", value: 0 },
                    ],
                },
            ],
        },
        {
            name: "Voices -> Ooh",
            rules: [
                {
                    name: "Voice Ooh",
                    propertyPatterns: [
                        { property: "instrumentId", pattern: "voice.*" },
                    ],
                    modifiers: [
                        { property: "midiBank", value: 0 },
                        { property: "midiProgram", value: 53 },
                    ],
                },
            ],
        },
        {
            name: "Choir Voices -> Strings",
            rules: [
                {
                    name: "Violin",
                    propertyPatterns: [
                        { property: "instrumentId", pattern: "voice.(soprano|mezzo|alto|female).*" },
                    ],
                    modifiers: [
                        { property: "midiBank", value: 0 },
                        { property: "midiProgram", value: 40 },
                    ],
                },
                {
                    name: "Cello",
                    propertyPatterns: [
                        { property: "instrumentId", pattern: "voice.(tenor|baritone|bass|male).*" },
                    ],
                    modifiers: [
                        { property: "midiBank", value: 0 },
                        { property: "midiProgram", value: 42 },
                    ],
                },
            ],
        },
    ];

    property var selectedMapping: 0;

    function forEach(array, callback) {
        for (var i = 0; i < array.length; i++) {
            var item = array[i];
            callback(item, i);
        }
    }

    function matchPropertyPattern(part, propertyPattern) {
        var property = propertyPattern.property;
        var pattern = propertyPattern.pattern;
        if (part == null || property == null || pattern == null) {
            return false;
        }
        if (!part.hasOwnProperty(property)) {
            return false;
        }
        var re = new RegExp(pattern);
        var matchResult = re.exec(part[property]);
        return matchResult != null;
    }

    function matchPart(part, rule) {
        if (rule.propertyPatterns) {
            return rule.propertyPatterns.every(function (propertyPattern) {
                return matchPropertyPattern(part, propertyPattern);
            });
        }
        return false;
    }

    function iterateChannels(part, callback) {
        forEach(part.instruments, function (instrument, instrumentIdx) {
            forEach(instrument.channels, function (channel, channelIdx) {
                callback(instrument, instrumentIdx, channel, channelIdx);
            });
        });
    }

    function applyModifiers(part, rule) {
        iterateChannels(part, function(instrument, instrumentIdx, channel, channelIdx) {
            forEach(rule.modifiers, function(modifier) {
                if (channel.hasOwnProperty(modifier.property)) {
                    channel[modifier.property] = modifier.value;
                }
            });
        });
    }

    function applyMapping(score, mapping) {
        forEach(score.parts, function (part) {
            forEach(mapping.rules, function (rule) {
                if (matchPart(part, rule)) {
                    applyModifiers(part, rule);
                }
            });
        });
    }

    function setMappingInfo(score, mapping, element) {
        element.text = "";
        forEach(score.parts, function (part, partIdx) {
            element.text += partIdx + " " + part.instrumentId;
            forEach(mapping.rules, function (rule) {
                if (matchPart(part, rule)) {
                    element.text += " -> " + rule.name;
                }
            });
            element.text += "\n";
        });
    }

    function changeSounds() {
        var mapping = defaultMappings[selectedMapping];
        curScore.startCmd();
        applyMapping(curScore, mapping);
        curScore.endCmd();
    }

    function updateView() {
        var mapping = defaultMappings[selectedMapping];
        setMappingInfo(curScore, mapping, mappingInfo);
    }

    function log(msg) {
        logText.text += msg + "\n";
    }

    function exitPlugin() {
        if (!(typeof quit === "function")) {
            Qt.quit();
        } else {
            quit();
        }
    }

    onRun: {
        if (mscoreMajorVersion >= 4) {
            title = "Quick Sound Select";
        }
    }

    Component.onCompleted: {
        if (!curScore) {
            log("Error: current score not available.");
            return;
        }
        log("parts: " + JSON.stringify(curScore.parts, null, 2));
        var mappingNames = defaultMappings.map(function (mapping) { return mapping.name; });
        comboBox.model = mappingNames;
        updateView();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 5

        ComboBox {
            id: comboBox
            Layout.fillWidth: true
            onActivated: {
                selectedMapping = comboBox.currentIndex;
                updateView();
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Text {
                id: mappingInfo
                Layout.fillWidth: true
                text: "(select mapping)"
            }
        }

        ScrollView {
            id: logView
            visible: false
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn
            clip: true

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Label {
                    id: logText
                    text: ""
                }
            }
        }

        Item {
           visible: !logView.visible
           Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "Show/Hide Log"
                onClicked: {
                    logView.visible = !logView.visible;
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                text: "Ok"
                onClicked: {
                    changeSounds();
                    exitPlugin()
                }
            }
            Button {
                text: "Cancel"
                onClicked: exitPlugin()
            }
        }
    }
}
