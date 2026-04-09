import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../seasons/providers/seasons_providers.dart';
import '../data/attendance_repo.dart';
import '../domain/attendance_entry.dart';

typedef AttendanceDatesQuery = ({
  String playerId,
  DateTime from,
  DateTime to,
});

typedef AttendanceWeekQuery = ({
  String seasonId,
  DateTime weekStart,
  DateTime weekEnd,
});

final attendanceRepoProvider = Provider<AttendanceRepo>((ref) {
  return AttendanceRepo(Supabase.instance.client);
});

final attendanceBySeasonAndDateProvider = FutureProvider.family<
    List<AttendanceEntry>,
    ({String seasonId, DateTime date})>((ref, args) async {
  return ref
      .read(attendanceRepoProvider)
      .listAttendanceBySeasonAndDate(args.seasonId, args.date);
});

final attendanceDatesByPlayerProvider =
    FutureProvider.family<List<DateTime>, AttendanceDatesQuery>(
        (ref, args) async {
  return ref.read(attendanceRepoProvider).listAttendanceDatesByPlayer(
        args.playerId,
        from: args.from,
        to: args.to,
      );
});

final attendanceForWeekProvider =
    FutureProvider.family<List<AttendanceEntry>, AttendanceWeekQuery>(
        (ref, args) async {
  return ref.read(attendanceRepoProvider).listAttendanceForWeek(
        seasonId: args.seasonId,
        weekStart: args.weekStart,
        weekEnd: args.weekEnd,
      );
});

final attendanceForActiveSeasonWeekProvider = FutureProvider.family<
    List<AttendanceEntry>,
    ({DateTime weekStart, DateTime weekEnd})>((ref, args) async {
  final season = await ref.watch(activeSeasonProvider.future);
  if (season == null) return const <AttendanceEntry>[];
  return ref.read(attendanceRepoProvider).listAttendanceForWeek(
        seasonId: season.id,
        weekStart: args.weekStart,
        weekEnd: args.weekEnd,
      );
});
