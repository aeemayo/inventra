import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  AppUser? _cachedUser;

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        _cachedUser = null;
        return null;
      }
      try {
        final user = await _fetchUserProfile(firebaseUser.uid);
        _cachedUser = user;
        return user;
      } catch (e) {
        // User exists in Auth but not in Firestore yet
        _cachedUser = null;
        return null;
      }
    });
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = await _fetchUserProfile(credential.user!.uid);
      _cachedUser = user;
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    } catch (e) {
      throw AuthFailure(message: e.toString());
    }
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user!.updateDisplayName(displayName);

      final now = DateTime.now();
      final userModel = UserModel(
        uid: credential.user!.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: role.name,
        phone: phone.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(FirestorePaths.users)
          .doc(credential.user!.uid)
          .set(userModel.toFirestore());

      final user = userModel.toEntity();
      _cachedUser = user;
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    } catch (e) {
      throw AuthFailure(message: e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _cachedUser = null;
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? fcmToken,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthFailure(message: 'Not authenticated');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (fcmToken != null) updates['fcmToken'] = fcmToken;

    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .update(updates);

    if (_cachedUser != null) {
      _cachedUser = _cachedUser!.copyWith(
        displayName: displayName ?? _cachedUser!.displayName,
        photoUrl: photoUrl ?? _cachedUser!.photoUrl,
        fcmToken: fcmToken ?? _cachedUser!.fcmToken,
      );
    }
  }

  @override
  Future<AppUser?> getUserById(String uid) async {
    try {
      return await _fetchUserProfile(uid);
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> _fetchUserProfile(String uid) async {
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .get();

    if (!doc.exists) {
      throw const AuthFailure(message: 'User profile not found');
    }

    return UserModel.fromFirestore(doc).toEntity();
  }
}
