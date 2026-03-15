import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePictureService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  // Pick image from gallery or camera
  Future<File?> pickImage({bool fromCamera = false}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,    // resize to save storage
      maxHeight: 512,
      imageQuality: 80, // compress to save storage
    );

    if (picked == null) return null;
    return File(picked.path);
  }

  // Upload image to Firebase Storage and save URL to Firestore
  Future<String?> uploadProfilePicture(File imageFile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      // Upload to Firebase Storage at users/{uid}/profile.jpg
      final ref = _storage.ref().child('users/$uid/profile.jpg');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save URL to Firestore
      await _firestore.collection('users').doc(uid).set(
        {'photoURL': downloadUrl},
        SetOptions(merge: true),
      );

      // Also update Firebase Auth profile
      await _auth.currentUser?.updatePhotoURL(downloadUrl);

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Delete current profile picture
  Future<void> deleteProfilePicture() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Delete from Storage
      await _storage.ref().child('users/$uid/profile.jpg').delete();

      // Remove from Firestore
      await _firestore.collection('users').doc(uid).set(
        {'photoURL': ''},
        SetOptions(merge: true),
      );

      await _auth.currentUser?.updatePhotoURL(null);
    } catch (e) {
      throw Exception('Failed to delete profile picture: $e');
    }
  }
}