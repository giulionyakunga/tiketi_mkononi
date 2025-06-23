import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiketi_mkononi/models/event.dart';

final selectedEventProvider = StateProvider<Event?>((ref) => null);
