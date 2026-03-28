import 'dart:typed_data'; // 💡 加入這一行來支援 Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'provider/onboarding_provider.dart';
import '../welcome/connection_painter.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final String initialRole;
  const OnboardingScreen({super.key, required this.initialRole});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillController = TextEditingController();
  final List<String> _skills = [];

  // 【關鍵修復】統一用 XFile，不用 File
  // XFile 在 Web 和 Native 都能正常讀取 bytes
  XFile? _imageFile;
  // 用於預覽的 bytes，Web 和 Native 都能用
  Future<Uint8List>? _imageBytesFuture;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _skillController.dispose();
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
        // 預先讀取 bytes 用於預覽（Web 和 Native 都走這條路）
        _imageBytesFuture = picked.readAsBytes();
      });
    }
  }

  Future<void> _submit() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請上傳一張頭像照片')),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫真實姓名')),
      );
      return;
    }

    try {
      await ref.read(onboardingNotifierProvider.notifier).submit(
            image: _imageFile!,
            name: _nameController.text.trim(),
            bio: _bioController.text.trim(),
            skills: _skills,
          );
      if (mounted) context.go('/swipe');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交失敗：$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(onboardingNotifierProvider);
    final themeColor = widget.initialRole == 'employer'
        ? Colors.purpleAccent
        : Colors.blueAccent;

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
                activeColor: themeColor.withValues(alpha: 0.5),
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
                        const Text(
                          '建立個人名片',
                          style: TextStyle(
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 圖片選取區（統一用 bytes 預覽）
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white10,
                              border: Border.all(color: themeColor, width: 2),
                            ),
                            child: _imageBytesFuture != null
                                ? ClipOval(
                                    child: FutureBuilder<Uint8List>(
                                      future: _imageBytesFuture,
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          // 統一用 Image.memory，Web 和 Native 都能用
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
                                    color: themeColor,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        _buildTextField(
                          _nameController,
                          '真實姓名',
                          Icons.person,
                          themeColor,
                        ),
                        const SizedBox(height: 20),

                        _buildTextField(
                          _bioController,
                          '個人簡介（選填）',
                          Icons.edit,
                          themeColor,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),

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
                            '輸入技能按 Enter',
                            Icons.bolt,
                            themeColor,
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
                                      themeColor.withValues(alpha: 0.2),
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
                              foregroundColor: themeColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              '完成連線',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(
      String label, IconData icon, Color color) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    Color color, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputStyle(label, icon, color),
    );
  }
}