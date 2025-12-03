import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  
  void _showDeleteAccountDialog() {
    // 🔹 SettingsScreen 의 context 를 로컬 변수로 캡처
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('계정 삭제'),
          content: const Text('정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // 다이얼로그만 닫기
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // 다이얼로그 닫기

                final authService = Provider.of<AuthService>(parentContext, listen: false);
                final success = await authService.deleteAccount();

                // 🔹 SettingsScreen 이 살아있는지 확인
                if (!mounted) return;

                // 🔹 SnackBar 는 SettingsScreen 의 context 로
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '계정 및 데이터를 삭제했습니다.'
                          : '계정 삭제에 실패했습니다. 최근 로그인 후 다시 시도해 주세요.',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );

                // 🔹 성공/실패 상관없이 SettingsScreen 닫고 싶으면:
                Navigator.pop(parentContext);

                // 만약 성공일 때만 닫고 싶으면 위 줄 대신:
                // if (success) Navigator.pop(parentContext);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }



  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => const _PasswordChangeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '완료',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '보안',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('비밀번호 변경'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showPasswordChangeDialog,
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '테마',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('라이트'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (value) {
              if (value != null) {
                themeProvider.setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('다크'),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (value) {
              if (value != null) {
                themeProvider.setThemeMode(value);
              }
            },
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '계정',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('내 계정 삭제', style: TextStyle(color: Colors.red)),
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }
}

// 비밀번호 변경 다이얼로그
class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  // ✅ 로딩 상태 추가
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ✅ 비밀번호 변경 로직 수정
  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // 로딩 시작
      });

      // AuthService 호출
      final authService = Provider.of<AuthService>(context, listen: false);
      
      final success = await authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false; // 로딩 종료
      });

      if (success) {
        Navigator.pop(context); // 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 비밀번호가 성공적으로 변경되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // 실패 시 (주로 현재 비밀번호가 틀렸을 때)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 비밀번호 변경 실패. 현재 비밀번호를 확인해주세요.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비밀번호 변경'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ... (TextFormField 들은 기존 코드 그대로 유지) ...
              
              // 현재 비밀번호
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: '현재 비밀번호',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrentPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? '현재 비밀번호를 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              
              // 새 비밀번호
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: '새 비밀번호',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '새 비밀번호를 입력하세요';
                  if (value.length < 6) return '비밀번호는 최소 6자 이상이어야 합니다';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 새 비밀번호 확인
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '새 비밀번호를 다시 입력하세요';
                  if (value != _newPasswordController.text) return '비밀번호가 일치하지 않습니다';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context), // 로딩 중 닫기 방지
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('변경'),
        ),
      ],
    );
  }
}
