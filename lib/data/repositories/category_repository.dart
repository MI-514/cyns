import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/sqlite_service.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch categories with fallback to local SQLite cache
  Future<List<CategoryModel>> getCategories() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(FirestoreCollections.categories)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<CategoryModel> categories = snapshot.docs
            .map((doc) => CategoryModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        // Save to SQLite local cache
        await SqliteService.instance.cacheCategories(categories);
        return categories;
      }
    } catch (_) {}

    // Fallback to SQLite cache or defaults
    List<CategoryModel> cached =
        await SqliteService.instance.getCachedCategories();
    if (cached.isNotEmpty) return cached;

    // Default built-in categories fallback
    return AppConstants.defaultCategories
        .map((cat) => CategoryModel(
              id: cat['id']!,
              name: cat['name']!,
              description: cat['description']!,
              icon: cat['icon']!,
            ))
        .toList();
  }

  /// Admin: Add Category
  Future<void> addCategory(CategoryModel category) async {
    await _firestore
        .collection(FirestoreCollections.categories)
        .doc(category.id)
        .set(category.toMap());
  }

  /// Admin: Update Category
  Future<void> updateCategory(CategoryModel category) async {
    await _firestore
        .collection(FirestoreCollections.categories)
        .doc(category.id)
        .update(category.toMap());
  }

  /// Admin: Delete/Deactivate Category
  Future<void> deleteCategory(String categoryId) async {
    await _firestore
        .collection(FirestoreCollections.categories)
        .doc(categoryId)
        .update({'isActive': false});
  }
}
