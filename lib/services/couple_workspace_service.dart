import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/couple_record.dart';
import '../data/models/media_model.dart';
import 'firebase_environment.dart';
import 'couple_activity_service.dart';

class CoupleWorkspaceService {
  static const enabled =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS') ||
      bool.fromEnvironment('USE_COUPLE_WORKSPACE');
  CoupleWorkspaceService({FirebaseFirestore? firestore})
    : _database = firestore;
  final FirebaseFirestore? _database;
  FirebaseFirestore get _db => _database ?? FirebaseEnvironment.firestore;
  DocumentReference<Map<String, dynamic>> _relation(String id) {
    requireDocumentId(id);
    return _db.collection('couple_relationships').doc(id);
  }

  String newId() => _db.collection('couple_relationships').doc().id;

  Stream<List<Map<String, dynamic>>> history(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('couple_history')
      .snapshots(includeMetadataChanges: true)
      .map((s) {
        if (s.metadata.isFromCache || s.metadata.hasPendingWrites) {
          throw StateError('Histórico não confirmado');
        }
        return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });

  Future<Map<String, dynamic>> relationship(String id) async {
    final doc = await _db
        .collection('partner_invites')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!confirmedSnapshot(doc) || doc.data()?['status'] != 'accepted') {
      throw StateError('Vínculo não consentido');
    }
    return doc.data()!;
  }

  Stream<List<CoupleRecord>> records(
    String id,
    String collection, {
    String? listId,
  }) {
    final ref = listId == null
        ? _relation(id).collection(collection)
        : _relation(id).collection('lists').doc(listId).collection('items');
    return ref.snapshots(includeMetadataChanges: true).map((s) {
      if (s.metadata.isFromCache || s.metadata.hasPendingWrites) {
        throw StateError('Dados não confirmados');
      }
      final rows = s.docs.map((d) => CoupleRecord(d.id, d.data())).toList();
      rows.sort(
        (a, b) => (b.data['createdAt'] as Timestamp).compareTo(
          a.data['createdAt'] as Timestamp,
        ),
      );
      return rows;
    });
  }

  Future<void> _write(
    String uid,
    String relationshipId,
    DocumentReference<Map<String, dynamic>> ref,
    int? expected,
    Map<String, dynamic> Function(Map<String, dynamic>?, List<String>) change, {
    bool withdrawal = false,
    bool audit = false,
  }) async {
    requireDocumentId(uid);
    CoupleConflict? conflict;
    try {
      await _db.runTransaction((tx) async {
        conflict = null;
        final invitation = (await tx.get(
          _db.collection('partner_invites').doc(relationshipId),
        )).data();
        if (invitation?['status'] != 'accepted') {
          throw StateError('Vínculo não consentido');
        }
        final members = [
          invitation!['senderUid'] as String,
          invitation['recipientUid'] as String,
        ];
        if (!members.contains(uid)) throw StateError('Participante inválido');
        final own = (await tx.get(_db.collection('users').doc(uid))).data();
        final other = members.firstWhere((id) => id != uid);
        // O perfil alheio é privado. Reciprocidade e bloqueios são validados
        // atomicamente pelas regras, inclusive se mudarem durante o commit.
        final active =
            own?['partnerUid'] == other &&
            own?['relationshipId'] == relationshipId;
        if (!active && !withdrawal) throw StateError('Vínculo encerrado');
        final current = (await tx.get(ref)).data();
        if ((expected == null && current != null) ||
            (expected != null && current?['version'] != expected)) {
          // Retry da mesma criação é idempotente; nunca redefine o conteúdo.
          if (expected == null && current?['authorId'] == uid) return;
          conflict = const CoupleConflict();
          throw conflict!;
        }
        final indexes = [
          for (final member in members)
            _db
                .collection('users')
                .doc(member)
                .collection('couple_history')
                .doc(relationshipId),
        ];
        final snapshots = [for (final index in indexes) await tx.get(index)];
        final next = change(current, members);
        next['updatedAt'] = FieldValue.serverTimestamp();
        next['version'] = (current?['version'] as int? ?? 0) + 1;
        tx.set(ref, next);
        if (audit) {
          tx.set(ref.collection('history').doc('${next['version']}'), next);
          tx.set(
            _relation(relationshipId).collection('activity').doc(ref.id),
            activityProjection(CoupleRecord(ref.id, next)),
          );
        }
        for (var i = 0; i < indexes.length; i++) {
          if (!snapshots[i].exists) {
            tx.set(indexes[i], {
              'relationshipId': relationshipId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (_) {
      if (conflict != null) throw conflict!;
      rethrow;
    }
  }

  Future<void> createList(
    String uid,
    String relation,
    String id,
    String title,
  ) {
    requireDocumentId(id);
    title = title.trim();
    requireText(title);
    if (title.length > 150) throw const FormatException('Título muito longo');
    return _write(
      uid,
      relation,
      _relation(relation).collection('lists').doc(id),
      null,
      (_, members) => {
        'schemaVersion': 1,
        'title': title,
        'authorId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> addItem(
    String uid,
    String relation,
    String listId,
    String id,
    CoupleSelection selection,
  ) {
    requireDocumentId(listId);
    requireDocumentId(id);
    return _write(
      uid,
      relation,
      _relation(
        relation,
      ).collection('lists').doc(listId).collection('items').doc(id),
      null,
      (_, members) => {
        'schemaVersion': 1,
        'selection': selection.toMap(),
        'authorId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'removed': false,
        'removedBy': null,
      },
    );
  }

  Future<void> removeItem(
    String uid,
    String relation,
    String listId,
    CoupleRecord item,
  ) => _write(
    uid,
    relation,
    _relation(
      relation,
    ).collection('lists').doc(listId).collection('items').doc(item.id),
    item.version,
    (old, members) => {...old!, 'removed': true, 'removedBy': uid},
  );

  Future<void> propose(
    String uid,
    String relation,
    String id,
    CoupleSelection selection,
    DateTime date, {
    CoupleRecord? previous,
  }) {
    requireDocumentId(id);
    final day = coupleDate(date);
    return _write(
      uid,
      relation,
      _relation(relation).collection('experiences').doc(id),
      previous?.version,
      (old, members) {
        if (old != null && old['authorId'] != uid) {
          throw StateError('Somente o autor corrige');
        }
        final revision = (old?['revision'] as int? ?? 0) + 1;
        return {
          'schemaVersion': 1,
          'authorId': uid,
          'participantIds': members,
          'selection': selection.toMap(),
          'occurredOn': day,
          'revision': revision,
          'responses': {
            ...?old?['responses'] as Map<String, dynamic>?,
            uid: {
              'revision': revision,
              'decision': 'confirmed',
              'respondedAt': FieldValue.serverTimestamp(),
            },
          },
          'createdAt': old?['createdAt'] ?? FieldValue.serverTimestamp(),
        };
      },
      audit: true,
    );
  }

  Future<void> respond(
    String uid,
    String relation,
    CoupleRecord record,
    String decision,
  ) {
    if (!const ['confirmed', 'declined', 'withdrawn'].contains(decision)) {
      throw ArgumentError('Resposta inválida');
    }
    return _write(
      uid,
      relation,
      _relation(relation).collection('experiences').doc(record.id),
      record.version,
      (old, members) => {
        ...old!,
        'responses': {
          ...old['responses'] as Map<String, dynamic>,
          uid: {
            'revision': old['revision'],
            'decision': decision,
            'respondedAt': FieldValue.serverTimestamp(),
          },
        },
      },
      withdrawal: decision == 'withdrawn',
      audit: true,
    );
  }
}
