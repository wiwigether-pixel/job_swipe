import 'dart:convert';
// 關鍵：根據平台引入不同的實作 (Stub 或 Web)
import 'profile_service_stub.dart' 
    if (dart.library.js_interop) 'profile_service_web.dart';


import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  Future<void> completeOnboarding({
    required XFile? imageFile,
    required String name,
    required String bio,
    required List<String> skills,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('未登入');

    debugPrint('[Storage] userId: ${user.id}');

    String? imageUrl;

    if (imageFile != null) {
      String extension = 'jpg';
      final fileName = imageFile.name;
      if (fileName.contains('.')) {
        extension = fileName.split('.').last.toLowerCase();
      }

      final storagePath = 'profiles/${user.id}.$extension';
      debugPrint('[Storage] 上傳路徑: $storagePath');

      final bytes = await imageFile.readAsBytes();
      debugPrint('[Storage] bytes 長度: ${bytes.length}');

      if (kIsWeb) {
        imageUrl = await _uploadViaJsSDK(
          storagePath: storagePath,
          bytes: bytes,
          extension: extension,
        );
      } else {
        try {
          // 行動端直接使用 supabase_flutter 的 uploadBinary
          await _client.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
          imageUrl = _client.storage.from('avatars').getPublicUrl(storagePath);
          debugPrint('[Storage] ✅ Native 上傳成功');
        } catch (e) {
          debugPrint('[Storage] ❌ Native 上傳失敗: $e');
          rethrow;
        }
      }
    }

    await _updateUserData(
      userId: user.id,
      name: name,
      bio: bio,
      skills: skills,
      imageUrl: imageUrl,
    );
  }

  Future<String?> _uploadViaJsSDK({
    required String storagePath,
    required List<int> bytes,
    required String extension,
  }) async {
    try {
      final accessToken = _client.auth.currentSession?.accessToken ?? '';
      if (accessToken.isEmpty) throw Exception('無法取得 access token');

      final base64Data = base64Encode(bytes);
      final contentType = 'image/$extension';

      debugPrint('[Storage] 透過 JS SDK 上傳...');

      // 呼叫條件引入定義的函式
      final jsResultString = await callWebUpload(
        storagePath: storagePath,
        base64Data: base64Data,
        contentType: contentType,
        accessToken: accessToken,
      );

      if (jsResultString == null) return null;
      final result = jsonDecode(jsResultString) as Map<String, dynamic>;

      if (result['success'] == true) {
        final imageUrl =
            '${_client.storage.from('avatars').getPublicUrl(storagePath)}'
            '?t=${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('[Storage] ✅ JS SDK 上傳成功');
        return imageUrl;
      } else {
        debugPrint('[Storage] ❌ JS SDK 失敗: ${result['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('[Storage] ❌ JS SDK 例外: $e');
      return null;
    }
  }

  Future<void> _updateUserData({
    required String userId,
    required String name,
    required String bio,
    required List<String> skills,
    required String? imageUrl,
  }) async {
    final updateData = <String, dynamic>{
      'display_name': name,
      'bio': bio,
      'skills': skills,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (imageUrl != null) {
      updateData['avatar_url'] = imageUrl;
    }

    await _client.from('users').update(updateData).eq('id', userId);
    debugPrint('[Storage] ✅ users 表更新成功');
  }
}