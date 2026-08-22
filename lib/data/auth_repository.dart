import 'package:firebase_auth/firebase_auth.dart';

/// طبقة الوصول لتسجيل الدخول عبر Firebase Authentication.
///
/// لا يوجد إنشاء حساب من داخل التطبيق — الحسابات (الإدمن) تُنشأ يدوياً
/// من Firebase Console فقط.
class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// يحوّل أكواد أخطاء FirebaseAuth إلى رسائل عربية واضحة للمستخدم.
  static String messageForError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        case 'invalid-email':
          return 'صيغة البريد الإلكتروني غير صحيحة.';
        case 'user-disabled':
          return 'تم تعطيل هذا الحساب.';
        case 'too-many-requests':
          return 'محاولات كثيرة فاشلة، الرجاء المحاولة لاحقاً.';
        case 'network-request-failed':
          return 'تعذّر الاتصال بالشبكة، تحقق من اتصالك بالإنترنت.';
        default:
          return 'حدث خطأ أثناء تسجيل الدخول: ${error.message ?? error.code}';
      }
    }
    return 'حدث خطأ غير متوقع، الرجاء المحاولة مرة أخرى.';
  }
}
