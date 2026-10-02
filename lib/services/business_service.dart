import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monetization_models.dart';

/// Firestore access for business listings. Collection: businesses/{id}
///
/// Listings are a directory product only. No payments, bookings, or money
/// transfers are handled here; premium tier upgrades are recorded as a label.
class BusinessService {
  // Lazily resolved so constructing this class never crashes when Firebase
  // has not been configured yet (methods only run while signed in).
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('businesses');

  /// Creates a listing. Privilege fields are always forced to safe values:
  /// status 'pending', free tier, not featured. Approval, tier upgrades,
  /// and featuring are admin actions, never owner self-service.
  Future<void> createListing(BusinessListing l) async {
    final data = l.toMap()
      ..['status'] = 'pending'
      ..['tier'] = BusinessTier.free.name
      ..['isFeatured'] = false;
    await _col.add(data);
  }

  /// Owner-safe update. Protected fields (ownerUid, tier, status,
  /// isFeatured, featuredUntil, isQuestStop, questPlaceId, createdAt) are
  /// stripped so they cannot be changed through this path even if a caller
  /// passes a mutated model. Featuring, quest-stop status, and tier upgrades
  /// are granted by verified purchases / admins only; [setStatus] and admin
  /// flows handle the rest.
  Future<void> updateListing(BusinessListing l) async {
    final data = l.toMap()
      ..remove('ownerUid')
      ..remove('tier')
      ..remove('status')
      ..remove('isFeatured')
      ..remove('featuredUntil')
      ..remove('isQuestStop')
      ..remove('questPlaceId')
      ..remove('createdAt');
    await _col.doc(l.id).update(data);
  }

  /// Admin path: approve or reject a listing ('approved' | 'rejected').
  Future<void> setStatus(String id, String status) async {
    await _col.doc(id).update({'status': status});
  }

  Stream<List<BusinessListing>> myListings(String uid) => _col
      .where('ownerUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => BusinessListing.fromMap(d.id, d.data())).toList());

  Stream<BusinessListing?> listingStream(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? BusinessListing.fromMap(d.id, d.data()!) : null);

  Stream<List<BusinessListing>> featuredBusinesses() => _col
      .where('status', isEqualTo: 'approved')
      .where('isFeatured', isEqualTo: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => BusinessListing.fromMap(d.id, d.data())).toList());
}
