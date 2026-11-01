import 'package:intl/intl.dart';

final DateFormat _timeFmt = DateFormat('hh:mm:ss a');
final DateFormat _timeMsFmt = DateFormat('hh:mm:ss.SSS a');
final DateFormat _dateTimeFmt = DateFormat('dd-MMM-yyyy hh:mm:ss a');

/// "02:14:05 PM"
String fmtTime12(DateTime dt) => _timeFmt.format(dt.toLocal());

/// "02:14:05.123 PM"
String fmtTime12Ms(DateTime dt) => _timeMsFmt.format(dt.toLocal());

/// "01-Nov-2026 02:14:05 PM"
String fmtDateTime12(DateTime dt) => _dateTimeFmt.format(dt.toLocal());
