import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:date_time_picker/date_time_picker.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  runApp(const ReminderApp());
}

Future<void> _initNotifications() async {
  // initialize timezone data
  tz.initializeTimeZones();
  try {
    final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    // fallback to local
    tz.setLocalLocation(tz.local);
  }

  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings iosInitializationSettings =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
    iOS: iosInitializationSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // handle tapped notification when app is in foreground/background
      // Could navigate to specific page if needed.
    },
  );

  // On iOS, also request permissions explicitly (already requested above via settings)
  await _requestPermissions();
}

Future<void> _requestPermissions() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  // For macOS (if targeting), you can also request here
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const ReminderHomePage(),
    );
  }
}

class ReminderHomePage extends StatefulWidget {
  const ReminderHomePage({Key? key}) : super(key: key);

  @override
  State<ReminderHomePage> createState() => _ReminderHomePageState();
}

class _ReminderHomePageState extends State<ReminderHomePage> {
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
  int _nextId = 0;
  final List<Map<String, dynamic>> _scheduled = [];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _scheduleReminder(String title, DateTime dateTime) async {
    final int id = _nextId++;
    final tz.TZDateTime scheduled = tz.TZDateTime.from(dateTime, tz.local);

    // Debug logging to help diagnose scheduling issues
    // (prints will appear in the debug/console output)
    // Example: Scheduling "Buy milk" at 2025-11-04 12:34:00.000
    // If this throws, the caller will surface the error to the user.
    debugPrint(
        'Scheduling reminder (id=$id): "$title" at ${scheduled.toLocal()}');

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Channel for reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      'Scheduled reminder at ${dateTime.toLocal()}',
      scheduled,
      platformDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Successfully scheduled with the plugin; now update in-memory list.
    setState(() {
      _scheduled.add({
        'id': id,
        'title': title,
        'time': dateTime,
      });
    });

    debugPrint('Reminder scheduled (id=$id) and added to list');
  }

  Future<void> _cancelReminder(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    setState(() {
      _scheduled.removeWhere((element) => element['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Reminder title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DateTimePicker(
              type: DateTimePickerType.dateTime,
              initialValue: _selectedDateTime.toString(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              icon: const Icon(Icons.event),
              dateLabelText: 'Date',
              timeLabelText: 'Time',
              onChanged: (val) {
                setState(() {
                  _selectedDateTime = DateTime.parse(val);
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final String title = _titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a title')),
                      );
                      return;
                    }

                    if (_selectedDateTime.isBefore(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pick a future time')),
                      );
                      return;
                    }

                    // Try scheduling and surface any error to the user.
                    try {
                      debugPrint(
                          'Request to schedule: "$title" at $_selectedDateTime');
                      await _scheduleReminder(title, _selectedDateTime);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder scheduled')),
                      );
                      _titleController.clear();
                    } catch (e, st) {
                      debugPrint('Failed to schedule reminder: $e\n$st');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to schedule: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.alarm_add),
                  label: const Text('Schedule'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    // show all pending notifications (ids) and clear UI list
                    final List<PendingNotificationRequest> pending =
                        await flutterLocalNotificationsPlugin
                            .pendingNotificationRequests();

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Pending notifications'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView(
                            shrinkWrap: true,
                            children: pending
                                .map((p) => ListTile(
                                      title: Text('${p.title ?? '-'}'),
                                      subtitle: Text(
                                          'id: ${p.id}, body: ${p.body ?? '-'}'),
                                    ))
                                .toList(),
                          ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'))
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.list),
                  label: const Text('Pending'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Scheduled reminders:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _scheduled.isEmpty
                  ? const Center(child: Text('No scheduled reminders'))
                  : ListView.builder(
                      itemCount: _scheduled.length,
                      itemBuilder: (context, index) {
                        final item = _scheduled[index];
                        return Card(
                          child: ListTile(
                            title: Text(item['title']),
                            subtitle: Text(item['time'].toLocal().toString()),
                            trailing: IconButton(
                              icon: const Icon(Icons.cancel,
                                  color: Colors.redAccent),
                              onPressed: () =>
                                  _cancelReminder(item['id'] as int),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
