import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  Timer? _timer;
  bool _isVerified = false;
  bool _canResend = false;
  int _resendCountdown = 60;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 이메일 인증 상태를 주기적으로 확인
  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final isVerified = await _authService.checkEmailVerified();
      
      if (isVerified && mounted) {
        setState(() {
          _isVerified = true;
        });
        
        _timer?.cancel();
        
        // 인증 완료 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이메일 인증이 완료되었습니다!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // 홈 화면으로 이동
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const NotionHomeScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  // 재전송 대기 카운트다운
  void _startResendCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  // 이메일 재전송
  Future<void> _resendEmail() async {
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });

    final success = await _authService.resendVerificationEmail();
    
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증 이메일을 다시 전송했습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      _startResendCountdown();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일 전송에 실패했습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _canResend = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text(
          '이메일 인증',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 이메일 아이콘
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 50,
                  color: Colors.blue,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 타이틀
              const Text(
                '이메일을 확인해주세요',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 설명
              Text(
                '${widget.email}\n위 이메일로 인증 링크를 보냈습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                '메일함에서 인증 링크를 클릭해주세요.\n(스팸 메일함도 확인해주세요)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 확인 중 표시
              if (!_isVerified) ...[
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '인증 확인 중...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              
              // 재전송 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _canResend ? _resendEmail : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: _canResend ? Colors.white30 : Colors.white12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    _canResend
                        ? '이메일 다시 보내기'
                        : '다시 보내기 ($_resendCountdown초)',
                    style: TextStyle(
                      fontSize: 14,
                      color: _canResend ? Colors.white : Colors.white38,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 나중에 하기 버튼
              TextButton(
                onPressed: () async {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  '나중에 인증하기',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
