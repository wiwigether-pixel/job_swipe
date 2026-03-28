// lib/core/services/profile_service_web.dart
import 'dart:js_interop';

@JS('initSupabaseJS')
external void initSupabaseJS(String url, String anonKey);

@JS('uploadImageToStorage')
external JSPromise<JSString> uploadImageToStorageJS(
  String bucket,
  String path,
  String base64Data,
  String contentType,
  String accessToken,
);

// 為了讓入口檔案能統一呼叫，我們包裝一個非 external 的 function
Future<String?> callWebUpload({
  required String storagePath,
  required String base64Data,
  required String contentType,
  required String accessToken,
}) async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  initSupabaseJS(url, anonKey);

  final jsResult = await uploadImageToStorageJS(
    'avatars',
    storagePath,
    base64Data,
    contentType,
    accessToken,
  ).toDart;

  return jsResult.toDart;
}