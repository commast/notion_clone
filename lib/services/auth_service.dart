// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String getCurrentUserId() {
    final user = _auth.currentUser;
    if (user != null) {
      return user.uid;
    }
    return ''; // 로그인 안 된 경우 빈 문자열 반환
  }

  // 회원가입 (이메일 + 비밀번호)
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 이메일 인증 링크 발송
      await userCredential.user?.sendEmailVerification();

      return {
        'success': true,
        'user': userCredential.user,
        'message': '회원가입 성공! 이메일을 확인해주세요.',
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
          break;
        case 'email-already-in-use':
          message = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          message = '유효하지 않은 이메일 형식입니다.';
          break;
        default:
          message = '회원가입 실패: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': '알 수 없는 오류가 발생했습니다: $e'};
    }
  }
  Future<bool> changePassword({
    required String currentPassword, 
    required String newPassword
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인된 사용자가 없습니다.');

      // 1. 재인증 (Re-authenticate): 보안상 중요 작업 전에는 본인 확인이 필요합니다.
      final email = user.email;
      if (email == null) throw Exception('이메일 정보를 찾을 수 없습니다.');
      
      AuthCredential credential = EmailAuthProvider.credential(
        email: email, 
        password: currentPassword
      );
      
      await user.reauthenticateWithCredential(credential);

      // 2. 비밀번호 변경
      await user.updatePassword(newPassword);
      
      return true;
    } catch (e) {
      debugPrint('비밀번호 변경 실패: $e');
      // 에러 메시지를 조금 더 구체적으로 처리하고 싶다면 여기서 throw e; 해도 됩니다.
      return false;
    }
  }
  
  // 로그인
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 이메일 인증 확인
      if (!userCredential.user!.emailVerified) {
        return {
          'success': false,
          'needVerification': true,
          'user': userCredential.user,
          'message': '이메일 인증이 필요합니다.',
        };
      }

      return {
        'success': true,
        'user': userCredential.user,
        'message': '로그인 성공!',
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = '등록되지 않은 이메일입니다.';
          break;
        case 'wrong-password':
          message = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          message = '유효하지 않은 이메일 형식입니다.';
          break;
        case 'user-disabled':
          message = '비활성화된 계정입니다.';
          break;
        default:
          message = '로그인 실패: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': '알 수 없는 오류가 발생했습니다: $e'};
    }
  }

  // 이메일 인증 메일 재전송
  Future<bool> resendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return true;
    } catch (e) {
      debugPrint('이메일 재전송 실패: $e');
      return false;
    }
  }

  // 이메일 인증 상태 확인
  Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('이메일 인증 확인 실패: $e');
      return false;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 비밀번호 재설정 이메일 발송
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      debugPrint('비밀번호 재설정 이메일 발송 실패: $e');
      return false;
    }
  }
}
