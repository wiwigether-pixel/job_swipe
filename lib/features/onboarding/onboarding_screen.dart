import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'provider/onboarding_provider.dart';
import '../welcome/connection_painter.dart';
import 'package:job_swipe/core/utils/logger.dart';
import 'package:job_swipe/core/providers/profile_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final String initialRole;
  final bool isRoleSwitch; 

  const OnboardingScreen({
    super.key,
    required this.initialRole,
    this.isRoleSwitch = false,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillController = TextEditingController();
  
  // 雇主專屬欄位
  final _companyNameController = TextEditingController();
  final _jobDescController = TextEditingController();
  String _companySize = '1-10';

  // 求職者專屬欄位
  int? _expectedSalary;
  final _salaryController = TextEditingController();

  final List<String> _skills = [];

  XFile? _imageFile;
  Future<Uint8List>? _imageBytesFuture;

  late AnimationController _animController;

  Color get _themeColor => switch (widget.initialRole) {
        'employer' => Colors.purpleAccent,
        'peer' => Colors.tealAccent,
        _ => Colors.blueAccent,
      };

  bool get _isEmployer => widget.initialRole == 'employer';
  bool get _isPeer => widget.initialRole == 'peer';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 預填已有的 profile 資料（避免用戶重複填寫）
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile != null) {
      if (profile.displayName.isNotEmpty && profile.displayName != '未命名') {
        _nameController.text = profile.displayName;
      }
      if (profile.bio != null) _bioController.text = profile.bio!;
      if (profile.companyName != null) {
        _companyNameController.text = profile.companyName!;
      }
      if (profile.skills.isNotEmpty) {
        _skills.addAll(profile.skills);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _skillController.dispose();
    _companyNameController.dispose();
    _jobDescController.dispose();
    _salaryController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() {
        _imageFile = picked;
        _imageBytesFuture = picked.readAsBytes();
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final companyName = _companyNameController.text.trim();

    final existingProfile = ref.read(profileProvider).valueOrNull;
    final hasExistingAvatar = existingProfile?.avatarUrl?.isNotEmpty == true;

    // 1. 基礎驗證：已有頭像則不強制上傳新圖
    if (!widget.isRoleSwitch && _imageFile == null && !hasExistingAvatar) {
      _showError('請上傳一張頭像照片');
      return;
    }
    if (name.isEmpty && !widget.isRoleSwitch && !hasExistingAvatar) {
      _showError('請填寫真實姓名');
      return;
    }

    // 2. 雇主身份檢查：必填公司名稱
    if (_isEmployer && companyName.isEmpty) {
      _showError('身為雇主，請填寫公司名稱');
      return;
    }

    try {
      if (widget.isRoleSwitch) {
        // 純身份切換：寫入 user_profiles 表
        await _saveRoleProfile(widget.initialRole);
      } else if (_imageFile != null) {
        // 有新頭像：走完整流程
        await ref.read(onboardingNotifierProvider.notifier).submit(
              image: _imageFile!,
              name: name,
              bio: _bioController.text.trim(),
              skills: _skills,
            );
        await _saveRoleProfile(widget.initialRole);
      } else {
        // 已有頭像，只需補齊缺少的欄位（如 company_name）
        await _saveRoleProfile(widget.initialRole);
      }

      // 強制刷新 Profile 狀態，讓 GoRouter redirect 看到最新資料
      ref.invalidate(profileProvider);
      await ref.read(profileProvider.future);

      if (mounted) context.go('/swipe');
    } catch (e) {
      _showError('提交失敗：$e');
    }
  }

  Future<void> _saveRoleProfile(String role) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('未登入');

    // 建立上傳資料 Map
    final data = <String, dynamic>{
      'user_id': user.id,
      'role': role,
      'bio': _bioController.text.trim(),
      'skills': _skills,
      'is_complete': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (_nameController.text.trim().isNotEmpty) {
      data['display_name'] = _nameController.text.trim();
    }

    // 🚀 角色互斥處理邏輯：
    // 當使用者變換角色時，清空不屬於該角色的欄位，避免 UserModel 判定邏輯混亂
    if (role == 'employer') {
      data['company_name'] = _companyNameController.text.trim();
      data['company_size'] = _companySize;
      data['job_description'] = _jobDescController.text.trim();
      
      // 雇主不應該有求職者欄位
      data['expected_salary'] = null; 
    } else if (role == 'peer') {
      // 同業交流
      data['company_name'] = null;
      data['expected_salary'] = null;
      data['company_size'] = null;
    } else {
      // 求職者
      data['expected_salary'] = _expectedSalary;
      
      // 求職者不應該有雇主欄位
      data['company_name'] = null;
      data['company_size'] = null;
      data['job_description'] = null;
    }

    logger.d('[Onboarding] 執行 UPSERT user_profiles: $data');

    await Supabase.instance.client
        .from('user_profiles')
        .upsert(data, onConflict: 'user_id,role');

    // 同步更新 users 表的角色欄位，讓 profileProvider 能讀到最新資料
    final usersUpdate = <String, dynamic>{
      'role': role,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (role == 'employer') {
      usersUpdate['company_name'] = _companyNameController.text.trim();
      usersUpdate['company_size'] = _companySize;
      usersUpdate['expected_salary'] = null;
    } else if (role == 'job_seeker') {
      usersUpdate['company_name'] = null;
      usersUpdate['company_size'] = null;
      usersUpdate['expected_salary'] = _expectedSalary;
      usersUpdate['skills'] = _skills;
    } else {
      usersUpdate['company_name'] = null;
      usersUpdate['company_size'] = null;
      usersUpdate['expected_salary'] = null;
    }

    logger.d('[Onboarding] 同步更新 users: $usersUpdate');

    await Supabase.instance.client
        .from('users')
        .update(usersUpdate)
        .eq('id', user.id);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(onboardingNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) => CustomPaint(
              painter: ConnectionPainter(
                progress: _animController.value,
                activeColor: _themeColor.withValues(alpha: 0.5),
              ),
              size: Size.infinite,
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Text(
                            widget.isRoleSwitch ? '建立$_roleLabel資料' : '建立個人名片',
                            style: const TextStyle(
                              fontSize: 26,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.isRoleSwitch)
                            Text(
                              '填寫完成後即可以$_roleLabel身份使用所有功能',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 30),

                          // 頭像（只在初始註冊時顯示）
                          if (!widget.isRoleSwitch) ...[
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white10,
                                  border:
                                      Border.all(color: _themeColor, width: 2),
                                ),
                                child: _imageBytesFuture != null
                                    ? ClipOval(
                                        child: FutureBuilder<Uint8List>(
                                          future: _imageBytesFuture,
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData) {
                                              return Image.memory(
                                                snapshot.data!,
                                                fit: BoxFit.cover,
                                              );
                                            }
                                            return const CircularProgressIndicator();
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.add_a_photo,
                                        size: 40,
                                        color: _themeColor,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildTextField(
                              _nameController,
                              '真實姓名',
                              Icons.person,
                            ),
                            const SizedBox(height: 20),
                          ],

                          _buildTextField(
                            _bioController,
                            _isEmployer ? '公司簡介（選填）' : '個人簡介（選填）',
                            Icons.edit,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),

                          // 🚀 雇主欄位
                          if (_isEmployer) ...[
                            _buildTextField(
                              _companyNameController,
                              '公司名稱',
                              Icons.business,
                            ),
                            const SizedBox(height: 20),
                            _buildDropdown(
                              label: '公司規模',
                              value: _companySize,
                              items: ['1-10', '11-50', '51-200', '200+'],
                              onChanged: (v) =>
                                  setState(() => _companySize = v!),
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              _jobDescController,
                              '職缺描述（選填）',
                              Icons.work,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 🚀 求職者欄位
                          if (!_isEmployer && !_isPeer) ...[
                            TextField(
                              controller: _salaryController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (v) =>
                                  _expectedSalary = int.tryParse(v),
                              decoration: _inputStyle(
                                '期望月薪（選填，單位：元）',
                                Icons.attach_money,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 技能輸入
                          TextField(
                            controller: _skillController,
                            onSubmitted: (val) {
                              final trimmed = val.trim();
                              if (trimmed.isNotEmpty) {
                                setState(() {
                                  _skills.add(trimmed);
                                  _skillController.clear();
                                });
                              }
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputStyle(
                              _isPeer ? '輸入技能/專長按 Enter' : '輸入技能按 Enter',
                              Icons.bolt,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: _skills
                                .map(
                                  (s) => Chip(
                                    label: Text(s),
                                    backgroundColor:
                                        _themeColor.withValues(alpha: 0.2),
                                    labelStyle:
                                        const TextStyle(color: Colors.white),
                                    onDeleted: () =>
                                        setState(() => _skills.remove(s)),
                                  ),
                                )
                                .toList(),
                          ),

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _themeColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                              ),
                              child: Text(
                                widget.isRoleSwitch ? '完成設定' : '完成連線',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String get _roleLabel => switch (widget.initialRole) {
        'employer' => '雇主',
        'peer' => '同業',
        _ => '求職者',
      };

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: _themeColor),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _themeColor),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputStyle(label, icon),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1A1A1A),
      style: const TextStyle(color: Colors.white),
      decoration: _inputStyle(label, Icons.people),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}