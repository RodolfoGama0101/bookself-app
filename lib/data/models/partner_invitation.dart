import 'package:cloud_firestore/cloud_firestore.dart';

/// O código é uma capacidade temporária. Nunca use um UID como código.
class PartnerInvitation {
  const PartnerInvitation({
    required this.code,
    required this.senderUid,
    this.senderEpoch = 0,
    required this.senderName,
    this.senderPhotoUrl,
    this.recipientUid,
    this.recipientEpoch,
    this.recipientName,
    this.recipientPhotoUrl,
    required this.createdAt,
    required this.status,
  });
  final String code;
  final String senderUid;
  final int senderEpoch;
  final String senderName;
  final String? senderPhotoUrl;
  final String? recipientUid;
  final int? recipientEpoch;
  final String? recipientName;
  final String? recipientPhotoUrl;
  final DateTime createdAt;
  final String status;
  DateTime get expiresAt => createdAt.add(const Duration(days: 7));
  bool isPendingAt(DateTime now) =>
      status == 'pending' && now.isBefore(expiresAt);
  static bool validCode(String code) =>
      RegExp(r'^[a-f0-9]{32}$').hasMatch(code);
  factory PartnerInvitation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (!validCode(doc.id) ||
        data == null ||
        data['version'] != 1 ||
        data['senderUid'] is! String ||
        (data['senderUid'] as String).isEmpty ||
        data['senderEpoch'] is! int ||
        data['senderEpoch'] < 0 ||
        (data['recipientEpoch'] != null && data['recipientEpoch'] is! int) ||
        (data['recipientUid'] != null && data['recipientUid'] is! String) ||
        (data['recipientName'] != null && data['recipientName'] is! String) ||
        (data['senderPhotoUrl'] != null && data['senderPhotoUrl'] is! String) ||
        (data['recipientPhotoUrl'] != null &&
            data['recipientPhotoUrl'] is! String) ||
        data.keys.toSet().difference({
          'version',
          'senderUid',
          'senderEpoch',
          'senderName',
          'senderPhotoUrl',
          'recipientUid',
          'recipientEpoch',
          'recipientName',
          'recipientPhotoUrl',
          'status',
          'createdAt',
          'decidedAt',
        }).isNotEmpty ||
        data['senderName'] is! String ||
        (data['senderName'] as String).isEmpty ||
        data['createdAt'] is! Timestamp ||
        ![
          'pending',
          'accepted',
          'declined',
          'cancelled',
        ].contains(data['status'])) {
      throw const FormatException('Convite inválido');
    }
    return PartnerInvitation(
      code: doc.id,
      senderUid: data['senderUid'],
      senderEpoch: data['senderEpoch'],
      senderName: data['senderName'],
      senderPhotoUrl: data['senderPhotoUrl'],
      recipientUid: data['recipientUid'],
      recipientEpoch: data['recipientEpoch'],
      recipientName: data['recipientName'],
      recipientPhotoUrl: data['recipientPhotoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'],
    );
  }
}

class InvitationResult<T> {
  const InvitationResult({this.value, this.error});
  final T? value;
  final String? error;
}

class PartnerInvitationException implements Exception {
  const PartnerInvitationException(this.message);
  final String message;
}
