import 'package:flutter/material.dart';
import '../data/models/category_model.dart';
import '../data/repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository = CategoryRepository();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String _selectedCategoryId = 'all';

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String get selectedCategoryId => _selectedCategoryId;

  CategoryProvider() {
    _initCategories();
  }

  Future<void> _initCategories() async {
    _isLoading = true;
    try {
      _categories = await _repository.getCategories();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _repository.getCategories();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  Future<void> addCategory(CategoryModel category) async {
    await _repository.addCategory(category);
    await fetchCategories();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _repository.updateCategory(category);
    await fetchCategories();
  }

  Future<void> deleteCategory(String categoryId) async {
    await _repository.deleteCategory(categoryId);
    await fetchCategories();
  }
}
