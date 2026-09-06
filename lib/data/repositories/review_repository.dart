import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add Review and Recalculate Worker Average Rating
  Future<void> addReview(ReviewModel review) async {
    // 1. Check duplicate review for the same completed job ID
    QuerySnapshot existing = await _firestore
        .collection(FirestoreCollections.reviews)
        .where('requestId', isEqualTo: review.requestId)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception("You have already submitted a review for this job.");
    }

    // 2. Add review doc
    await _firestore
        .collection(FirestoreCollections.reviews)
        .add(review.toMap());

    // 3. Mark service request as reviewed
    await _firestore
        .collection(FirestoreCollections.serviceRequests)
        .doc(review.requestId)
        .update({'hasBeenReviewed': true});

    // 4. Update Worker's rating & review count
    QuerySnapshot workerReviews = await _firestore
        .collection(FirestoreCollections.reviews)
        .where('workerId', isEqualTo: review.workerId)
        .get();

    double totalRating = 0;
    int count = workerReviews.docs.length;

    for (var doc in workerReviews.docs) {
      totalRating += (doc.get('rating') as num).toDouble();
    }

    double avgRating = count > 0 ? (totalRating / count) : 0.0;

    await _firestore
        .collection(FirestoreCollections.workers)
        .doc(review.workerId)
        .update({
      'rating': double.parse(avgRating.toStringAsFixed(1)),
      'reviewCount': count,
    });
  }

  /// Stream of worker reviews
  Stream<List<ReviewModel>> getWorkerReviews(String workerId) {
    return _firestore
        .collection(FirestoreCollections.reviews)
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromMap(
                doc.data(), doc.id))
            .toList());
  }
}
