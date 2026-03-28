import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/profile_service.dart';

final profileServiceProvider = Provider((ref) => ProfileService());

final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  final service = ref.read(profileServiceProvider);
  return OnboardingNotifier(service);
});

class OnboardingNotifier extends StateNotifier<bool> {
  final ProfileService _service;

  OnboardingNotifier(this._service) : super(false);

  /// 使用 XFile 取代 File，同時相容 Web 和 Native
  Future<void> submit({
    required XFile image,
    required String name,
    required String bio,
    required List<String> skills,
  }) async {
    state = true;
    try {
      await _service.completeOnboarding(
        imageFile: image,
        name: name,
        bio: bio,
        skills: skills,
      );
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }
}