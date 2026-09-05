import 'package:job_swipe/core/utils/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/user_model.dart';
import '../../features/auth/presentation/auth_provider.dart';

part 'profile_provider.g.dart';

@Riverpod(keepAlive: true)
Future<UserModel?> profile(ProfileRef ref) async {
  final supabase = Supabase.instance.client;

  final authAsync = ref.watch(authStateProvider);
  final userId = supabase.auth.currentUser?.id ?? authAsync.valueOrNull?.id;

  logger.i('[Profile] fetch: userId=$userId');
  if (userId == null) return null;

  final rows = await supabase.rpc('get_my_profile') as List;
  if (rows.isEmpty) return null;
  return UserModel.fromSupabase(Map<String, dynamic>.from(rows.first as Map));
}