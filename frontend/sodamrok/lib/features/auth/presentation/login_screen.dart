import 'package:flutter/material.dart';

import '../application/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.controller,
    this.showBackButton = false,
    this.popOnSuccess = false,
  });

  final AuthController controller;
  final bool showBackButton;
  final bool popOnSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _didPopAfterSuccess = false;
  final _emailController = TextEditingController(text: 'demo@example.com');
  final _passwordController = TextEditingController(text: 'DemoPass123!');
  bool _obscurePassword = true;

  AuthController get _controller => widget.controller;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final status = _controller.status;
        final isLoading = status == AuthStatus.authenticating;
        final error = _controller.error;

        if (widget.popOnSuccess && !_didPopAfterSuccess && _controller.isAuthenticated && Navigator.of(context).canPop()) {
          _didPopAfterSuccess = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F2),
          appBar: widget.showBackButton
              ? AppBar(
                  title: const Text('로그인'),
                  leading: const BackButton(),
                )
              : null,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE4E0D8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '소담록 로그인',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F3A36),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '데모 계정으로 로그인하거나 팀 계정을 입력해 주세요.',
                              style: TextStyle(color: Color(0xFF5C6D68)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: '이메일',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '이메일을 입력해 주세요.';
                                }
                                if (!value.contains('@')) {
                                  return '올바른 이메일 주소가 아니에요.';
                                }
                                return null;
                              },
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: '비밀번호',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: isLoading
                                      ? null
                                      : () => setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          }),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '비밀번호를 입력해 주세요.';
                                }
                                if (value.length < 8) {
                                  return '비밀번호는 8자 이상이어야 합니다.';
                                }
                                return null;
                              },
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 24),
                            if (error != null) ...[
                              Text(
                                error,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                            ],
                            FilledButton(
                              onPressed: isLoading ? null : _onSubmit,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('로그인'),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '처음 접속이라면 README의 시드 명령으로 데모 데이터를 생성한 뒤,\n데모 계정으로 로그인할 수 있습니다.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF5C6D68)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: isLoading ? null : _openRegister,
                                  child: const Text('회원가입'),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: isLoading ? null : _openPasswordReset,
                                  child: const Text('비밀번호 재설정'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onSubmit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    await _controller.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (widget.popOnSuccess && mounted && !_didPopAfterSuccess && _controller.isAuthenticated && Navigator.of(context).canPop()) {
      _didPopAfterSuccess = true;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openRegister() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RegisterSheet(controller: _controller),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료됐어요.')),
      );
    }
  }

  Future<void> _openPasswordReset() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ResetPasswordSheet(controller: _controller),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 재설정했어요. 새로운 비밀번호로 로그인해 주세요.')),
      );
    }
  }
}

class RegisterSheet extends StatefulWidget {
  const RegisterSheet({super.key, required this.controller});

  final AuthController controller;

  @override
  State<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '회원가입',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해 주세요.';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 주소가 아니에요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: '이름 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해 주세요.';
                      }
                      if (value.length < 8) {
                        return '비밀번호는 8자 이상이어야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      labelText: '비밀번호 확인',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return '비밀번호가 일치하지 않아요.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            FilledButton(
              onPressed: _isLoading ? null : _onSubmit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('가입 후 로그인하기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final message = await widget.controller.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _displayNameController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (message == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }
}

class ResetPasswordSheet extends StatefulWidget {
  const ResetPasswordSheet({super.key, required this.controller});

  final AuthController controller;

  @override
  State<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '비밀번호 재설정',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해 주세요.';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 주소가 아니에요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '새 비밀번호',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '새 비밀번호를 입력해 주세요.';
                      }
                      if (value.length < 8) {
                        return '비밀번호는 8자 이상이어야 합니다.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      labelText: '비밀번호 확인',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return '비밀번호가 일치하지 않아요.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            FilledButton(
              onPressed: _isLoading ? null : _onSubmit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('비밀번호 재설정'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final message = await widget.controller.resetPassword(
      email: _emailController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (message == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }
}

Future<bool?> showLoginModal(BuildContext context, AuthController controller) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => LoginScreen(
        controller: controller,
        showBackButton: true,
        popOnSuccess: true,
      ),
      fullscreenDialog: true,
    ),
  );
}

