#!/bin/bash
set -u

REPORT="$HOME/Desktop/LayoutSwitch-diagnostics-$(date +%Y%m%d-%H%M%S)-$$.txt"
APP="/Applications/LayoutSwitch.app"

if ! {
    printf 'LayoutSwitch diagnostics\nCollected: '
    date '+%Y-%m-%d %H:%M:%S %Z'
    sw_vers
    printf '\nArchitecture: '
    uname -m
    printf '\nInstalled app: %s\n' "$APP"
    if [ -x "$APP/Contents/MacOS/LayoutSwitch" ]; then
        printf 'Version: '
        /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
        printf 'Build: '
        /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"
        printf '\nRead-only diagnostic snapshot (Terminal permission context):\n'
        "$APP/Contents/MacOS/LayoutSwitch" --diagnose
    else
        printf 'LayoutSwitch.app was not found in /Applications.\n'
    fi
    printf '\nSystem log for the last hour:\n'
    /usr/bin/log show --last 1h --style compact --predicate 'subsystem == "local.masos.LayoutSwitch"'
} > "$REPORT" 2>&1; then
    printf '\nНе удалось собрать все данные. Проверьте сообщения в отчёте.\n'
fi

if [ -f "$REPORT" ]; then
    printf '\nОтчёт сохранён на рабочий стол:\n%s\nПрикрепите этот файл в чат и укажите примерное время сбоя.\n' "$REPORT"
else
    printf '\nНе удалось создать отчёт на рабочем столе.\n'
    exit 1
fi
