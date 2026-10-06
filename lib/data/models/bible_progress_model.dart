import 'package:cloud_firestore/cloud_firestore.dart';

class BibleProgressModel {
  final String id; // Composto como "userId_bookName"
  final String userId;
  final String bookName;
  final List<int> readChapters; // Lista de capítulos lidos
  final DateTime updatedAt;
  final bool isShared;

  BibleProgressModel({
    required this.id,
    required this.userId,
    required this.bookName,
    required this.readChapters,
    required this.updatedAt,
    this.isShared = true,
  });

  factory BibleProgressModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BibleProgressModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      isShared: data['isShared'] != false,
      bookName: data['bookName'] ?? '',
      readChapters: List<int>.from(data['readChapters'] ?? []),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isShared': isShared,
      'bookName': bookName,
      'readChapters': readChapters,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BibleProgressModel copyWith({
    String? id,
    String? userId,
    String? bookName,
    List<int>? readChapters,
    DateTime? updatedAt,
    bool? isShared,
  }) {
    return BibleProgressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookName: bookName ?? this.bookName,
      readChapters: readChapters ?? this.readChapters,
      updatedAt: updatedAt ?? this.updatedAt,
      isShared: isShared ?? this.isShared,
    );
  }
}
