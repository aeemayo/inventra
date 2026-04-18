import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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
    required String shopName,
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
        shopName: shopName.trim(),
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
    String? phoneNumber,
    String? shopName,
    String? fcmToken,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthFailure(message: 'Not authenticated');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (shopName != null) updates['shopName'] = shopName;
    if (fcmToken != null) updates['fcmToken'] = fcmToken;

    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .update(updates);

    if (_cachedUser != null) {
      _cachedUser = _cachedUser!.copyWith(
        displayName: displayName ?? _cachedUser!.displayName,
        photoUrl: photoUrl ?? _cachedUser!.photoUrl,
        phoneNumber: phoneNumber ?? _cachedUser!.phoneNumber,
        shopName: shopName ?? _cachedUser!.shopName,
        fcmToken: fcmToken ?? _cachedUser!.fcmToken,
      );
    }
  }

  @override
  Future<String> uploadProfilePhoto(String filePath) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthFailure(message: 'Not authenticated');

    try {
      final file = File(filePath);

      // Verify the file exists and is readable
      if (!await file.exists()) {
        debugPrint('[ProfilePhoto] File does not exist: $filePath');
        throw const AuthFailure(message: 'Selected image file not found');
      }

      final fileSize = await file.length();
      debugPrint('[ProfilePhoto] File size: $fileSize bytes');
      debugPrint('[ProfilePhoto] Storage bucket: ${FirebaseStorage.instance.bucket}');

      // Read bytes first to avoid file-access issues during upload
      final bytes = await file.readAsBytes();
      debugPrint('[ProfilePhoto] Read ${bytes.length} bytes, uploading...');

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes * 100;
          debugPrint(
              '[ProfilePhoto] Upload progress: ${progress.toStringAsFixed(1)}% '
              '(${snapshot.bytesTransferred}/${snapshot.totalBytes}) '
              'state=${snapshot.state}');
        },
        onError: (e) {
          debugPrint('[ProfilePhoto] Upload stream error: $e');
        },
      );

      await uploadTask;
      debugPrint('[ProfilePhoto] Upload complete, fetching download URL...');

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('[ProfilePhoto] Download URL: $downloadUrl');

      // Persist the URL in Firestore + update cached user
      await updateProfile(photoUrl: downloadUrl);

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('[ProfilePhoto] FirebaseException: code=${e.code} message=${e.message} plugin=${e.plugin}');
      throw AuthFailure(message: e.message ?? 'Failed to upload photo');
    } catch (e, stack) {
      debugPrint('[ProfilePhoto] Error: $e');
      debugPrint('[ProfilePhoto] Stack: $stack');
      throw AuthFailure(message: 'Failed to upload photo: $e');
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
