# Reminder App 
Phan Thi Chi -22git
A minimal Flutter Reminder app that schedules local notifications using `flutter_local_notifications` and a `DateTimePicker` UI.


Uploading Screen Recording 2025-11-04 at 00.25.55.mov…


Features
- Schedule a reminder with a custom title and date/time.
- Uses zoned notifications (timezone-aware) so reminders fire at the intended local time.
- Shows a list of scheduled reminders and allows cancelling them.

Dependencies
- flutter_local_notifications
- date_time_picker
- timezone
- flutter_native_timezone

Notes
- For Android, notifications work in emulators and devices. To persist across device reboot you'd need to add BOOT_COMPLETED handling (not included).
- For iOS, you must request and grant notification permission. Also add required entitlements if testing on a real device.

How to run
1. From the project root run:

```bash
flutter pub get
flutter run
```

2. Test by scheduling a reminder a minute or two into the future.

Permissions and platform specifics
- Android: uses the app icon `@mipmap/ic_launcher` for notifications. If you customize icons, update `AndroidInitializationSettings` accordingly.
- iOS: ensure you add necessary permissions in `Info.plist` when running on a physical iOS device.

Next steps / improvements
- Persist scheduled reminders in local storage (shared_preferences, sqflite, hive).
- Restore scheduled reminders after device reboot.
- Add repeat options and snooze.

