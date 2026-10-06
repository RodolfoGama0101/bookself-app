import 'package:cloud_firestore/cloud_firestore.dart';

enum _CopyWithValue { unchanged }

class BookModel {
  final String id;
  final String userId;
  final String title;
  final List<String> authors;
  final String coverUrl;
  final String status; // "Quero Ler", "Lendo", "Lido"
  final String publishedDate;
  final DateTime? finishedDate; // Data personalizada selecionada pelo usuário
  final DateTime addedAt;
  final String? googleBooksId;
  final bool isShared;
  final DateTime? activityAt;
  final bool feedVisible;

  BookModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.authors,
    required String coverUrl,
    required this.status,
    required this.publishedDate,
    this.finishedDate,
    required this.addedAt,
    this.googleBooksId,
    this.isShared = true,
    this.activityAt,
    this.feedVisible = true,
  }) : coverUrl = coverUrl.startsWith('http://')
           ? coverUrl.replaceFirst('http://', 'https://')
           : coverUrl;

  factory BookModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BookModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'Sem Título',
      authors: List<String>.from(data['authors'] ?? []),
      coverUrl: data['coverUrl'] ?? '',
      status: data['status'] ?? 'Quero Ler',
      publishedDate: data['publishedDate'] ?? '',
      finishedDate: (data['finishedDate'] as Timestamp?)?.toDate(),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      googleBooksId: data['googleBooksId'] as String?,
      isShared: data['isShared'] != false,
      activityAt: (data['activityAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'authors': authors,
      'coverUrl': coverUrl,
      'status': status,
      'publishedDate': publishedDate,
      'finishedDate': finishedDate != null
          ? Timestamp.fromDate(finishedDate!)
          : null,
      'addedAt': Timestamp.fromDate(addedAt),
      if (googleBooksId != null) 'googleBooksId': googleBooksId,
      'isShared': isShared,
      if (activityAt != null) 'activityAt': Timestamp.fromDate(activityAt!),
    };
  }

  /// [finishedDate] aceita DateTime ou null: omitido preserva, null limpa.
  BookModel copyWith({
    String? id,
    String? userId,
    String? title,
    List<String>? authors,
    String? coverUrl,
    String? status,
    String? publishedDate,
    bool? isShared,
    bool? feedVisible,
    Object? finishedDate = _CopyWithValue.unchanged,
    DateTime? addedAt,
    Object? googleBooksId = _CopyWithValue.unchanged,
  }) {
    return BookModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      publishedDate: publishedDate ?? this.publishedDate,
      isShared: isShared ?? this.isShared,
      activityAt: activityAt,
      feedVisible: feedVisible ?? this.feedVisible,
      finishedDate: identical(finishedDate, _CopyWithValue.unchanged)
          ? this.finishedDate
          : finishedDate as DateTime?,
      addedAt: addedAt ?? this.addedAt,
      googleBooksId: identical(googleBooksId, _CopyWithValue.unchanged)
          ? this.googleBooksId
          : googleBooksId as String?,
    );
  }
}
