// lib/screens/auth/auth_screen.dart
// Màn hình đăng ký và đăng nhập bằng Supabase Auth.
// Đăng nhập thành công: ApiClient đổi trạng thái đăng nhập, router tự chuyển về Trang chủ.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/primary_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _isLogin = true;
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // Hiện lý do bị đưa về màn đăng nhập (VD: phiên hết hạn) rồi xóa đi.
    _error = ApiClient.instance.sessionMessage;
    ApiClient.instance.sessionMessage = null;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _notice = null;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_isLogin) {
        await ApiClient.instance.login(_email.text, _password.text);
      } else {
        final signedIn = await ApiClient.instance.register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
        if (!signedIn && mounted) {
          setState(() {
            _isLogin = true;
            _loading = false;
            _password.clear();
            _confirm.clear();
            _notice = 'Hãy mở email xác nhận tài khoản. Sau khi xác nhận, quay lại đây để đăng nhập.';
          });
        }
      }
      // Thành công: router tự chuyển trang và Provider được dựng lại, không cần setState.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kScreenPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Text('🎓', style: TextStyle(fontSize: 56))),
                    const Gap(kSpaceSM),
                    Text('EduQuest', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                    const Gap(4),
                    Text(
                      _isLogin ? 'Đăng nhập để tiếp tục học' : 'Tạo tài khoản mới',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Gap(kSpaceXL),
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.person_outline)),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui lòng nhập họ tên.' : null,
                      ),
                      const Gap(kSpaceMD),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Vui lòng nhập email.';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Email không hợp lệ.';
                        return null;
                      },
                    ),
                    const Gap(kSpaceMD),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                      onFieldSubmitted: (_) {
                        if (_isLogin && !_loading) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.isEmpty) return 'Vui lòng nhập mật khẩu.';
                        if (!_isLogin && text.length < 8) return 'Mật khẩu tối thiểu 8 ký tự.';
                        return null;
                      },
                    ),
                    if (!_isLogin) ...[
                      const Gap(kSpaceMD),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_loading) _submit();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Nhập lại mật khẩu',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        validator: (value) => value != _password.text ? 'Mật khẩu nhập lại không khớp.' : null,
                      ),
                    ],
                    if (_notice != null) ...[
                      const Gap(kSpaceMD),
                      Text(_notice!, textAlign: TextAlign.center),
                    ],
                    if (_error != null) ...[
                      const Gap(kSpaceMD),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                    ],
                    const Gap(kSpaceLG),
                    PrimaryButton(
                      text: _isLogin ? 'Đăng nhập' : 'Đăng ký',
                      icon: _isLogin ? Icons.login_rounded : Icons.person_add_alt_1_rounded,
                      isLoading: _loading,
                      onPressed: _loading ? null : _submit,
                    ),
                    const Gap(kSpaceSM),
                    TextButton(
                      onPressed: _loading ? null : _switchMode,
                      child: Text(_isLogin ? 'Chưa có tài khoản? Đăng ký' : 'Đã có tài khoản? Đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
