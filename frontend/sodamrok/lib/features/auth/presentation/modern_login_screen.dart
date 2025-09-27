import 'package:flutter/material.dart';
import '../application/auth_controller.dart';

class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({
    super.key,
    required this.controller,
    this.showBackButton = false,
    this.popOnSuccess = false,
  });

  final AuthController controller;
  final bool showBackButton;
  final bool popOnSuccess;

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _didPopAfterSuccess = false;
  final _emailController = TextEditingController(text: 'demo@example.com');
  final _passwordController = TextEditingController(text: 'DemoPass123!');
  bool _obscurePassword = true;
  bool _showEmailLogin = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AuthController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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

        if (widget.popOnSuccess &&
            !_didPopAfterSuccess &&
            _controller.isAuthenticated &&
            Navigator.of(context).canPop()) {
          _didPopAfterSuccess = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          });
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: widget.showBackButton
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              : null,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // POI 캐릭터 로고
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/POI.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      '소담록에 오신걸 환영해요',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '일상의 소중한 순간들을 기록해보세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // 소셜 로그인 버튼들
                    if (!_showEmailLogin) ...[
                      _SocialLoginButton(
                        icon: Icons.g_mobiledata,
                        label: 'Google로 계속하기',
                        color: Colors.white,
                        textColor: Colors.black87,
                        borderColor: Colors.grey.shade300,
                        onPressed: isLoading ? null : () => _handleSocialLogin('google'),
                      ),

                      const SizedBox(height: 12),

                      _SocialLoginButton(
                        icon: Icons.chat_bubble,
                        label: '카카오로 계속하기',
                        color: const Color(0xFFFFE812),
                        textColor: Colors.black87,
                        onPressed: isLoading ? null : () => _handleSocialLogin('kakao'),
                      ),

                      const SizedBox(height: 12),

                      _SocialLoginButton(
                        icon: Icons.apple,
                        label: 'Apple로 계속하기',
                        color: Colors.black,
                        textColor: Colors.white,
                        onPressed: isLoading ? null : () => _handleSocialLogin('apple'),
                      ),

                      const SizedBox(height: 24),

                      // 구분선
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '또는',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 이메일로 로그인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () {
                            setState(() {
                              _showEmailLogin = true;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '이메일로 로그인',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 이메일 로그인 폼
                    if (_showEmailLogin) ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // 이메일 입력
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: '이메일 주소',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(20),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '이메일을 입력해 주세요';
                                  }
                                  if (!value.contains('@')) {
                                    return '올바른 이메일 주소를 입력해 주세요';
                                  }
                                  return null;
                                },
                                enabled: !isLoading,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 비밀번호 입력
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: '비밀번호',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey,
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
                                    return '비밀번호를 입력해 주세요';
                                  }
                                  return null;
                                },
                                enabled: !isLoading,
                              ),
                            ),

                            const SizedBox(height: 24),

                            if (error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 로그인 버튼
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _onSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B73FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        '로그인',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 돌아가기 버튼
                            TextButton(
                              onPressed: isLoading ? null : () {
                                setState(() {
                                  _showEmailLogin = false;
                                });
                              },
                              child: Text(
                                '다른 방법으로 로그인',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 하단 링크들
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : _openRegister,
                          child: Text(
                            '회원가입',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        TextButton(
                          onPressed: isLoading ? null : _openPasswordReset,
                          child: Text(
                            '비밀번호 찾기',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSocialLogin(String provider) async {
    // Mock 소셜 로그인 구현
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${provider.toUpperCase()} 로그인 성공! (Mock)'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // 실제로는 여기서 소셜 로그인 API를 호출하고
      // 성공 시 _controller.loginWithSocial() 같은 메서드를 호출
      await Future.delayed(const Duration(milliseconds: 1500));

      // Demo용으로 일반 로그인 진행
      await _controller.login(
        email: 'demo@example.com',
        password: 'DemoPass123!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$provider 로그인에 실패했습니다'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
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

    if (widget.popOnSuccess &&
        mounted &&
        !_didPopAfterSuccess &&
        _controller.isAuthenticated &&
        Navigator.of(context).canPop()) {
      _didPopAfterSuccess = true;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openRegister() async {
    // 회원가입 구현 (현재 기존 로직 유지)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원가입 기능은 추후 구현 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPasswordReset() async {
    // 비밀번호 찾기 구현 (현재 기존 로직 유지)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('비밀번호 찾기 기능은 추후 구현 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: textColor,
          size: 24,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          side: borderColor != null ? BorderSide(color: borderColor!) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }
}

// 새로운 로그인 화면을 사용하는 헬퍼 함수
Future<bool?> showModernLoginModal(BuildContext context, AuthController controller) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ModernLoginScreen(
        controller: controller,
        showBackButton: true,
        popOnSuccess: true,
      ),
      fullscreenDialog: true,
    ),
  );
}