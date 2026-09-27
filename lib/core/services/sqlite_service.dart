import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/category_model.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._init();
  static Database? _database;

  SqliteService._init();

  Future<Database?> get database async {
    try {
      if (_database != null) return _database!;
      _database = await _initDB('cyns_local.db');
      return _database;
    } catch (_) {
      return null;
    }
  }

  Future<Database?> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: (db, oldVersion, newVersion) async {
          await _createDB(db, newVersion);
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    try {
      // Categories table for offline browsing
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          icon TEXT NOT NULL,
          isActive INTEGER NOT NULL
        )
      ''');

      // Recently viewed workers
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recent_workers (
          workerId TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          profession TEXT NOT NULL,
          rating REAL NOT NULL,
          profilePicUrl TEXT,
          viewedAt INTEGER NOT NULL
        )
      ''');

      // Offline Service Request Drafts
      await db.execute('''
        CREATE TABLE IF NOT EXISTS request_drafts (
          id TEXT PRIMARY KEY,
          workerId TEXT NOT NULL,
          categoryId TEXT NOT NULL,
          problemDescription TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    } catch (_) {}
  }

  // --- Category Cache Methods ---
  Future<void> cacheCategories(List<CategoryModel> categories) async {
    try {
      final db = await instance.database;
      if (db == null) return;
      final batch = db.batch();
      batch.delete('categories');
      for (var cat in categories) {
        batch.insert(
          'categories',
          {
            'id': cat.id,
            'name': cat.name,
            'description': cat.description,
            'icon': cat.icon,
            'isActive': cat.isActive ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<CategoryModel>> getCachedCategories() async {
    try {
      final db = await instance.database;
      if (db == null) return [];
      final maps = await db.query('categories');
      if (maps.isEmpty) return [];
      return maps
          .map((map) => CategoryModel(
                id: map['id'] as String,
                name: map['name'] as String,
                description: map['description'] as String,
                icon: map['icon'] as String,
                isActive: (map['isActive'] as int) == 1,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Recent Workers Methods ---
  Future<void> saveRecentWorker({
    required String workerId,
    required String name,
    required String profession,
    required double rating,
    required String profilePicUrl,
  }) async {
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.insert(
        'recent_workers',
        {
          'workerId': workerId,
          'name': name,
          'profession': profession,
          'rating': rating,
          'profilePicUrl': profilePicUrl,
          'viewedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getRecentWorkers() async {
    try {
      final db = await instance.database;
      if (db == null) return [];
      return await db.query(
        'recent_workers',
        orderBy: 'viewedAt DESC',
        limit: 10,
      );
    } catch (_) {
      return [];
    }
  }

  // --- Offline Request Drafts ---
  Future<void> saveRequestDraft({
    required String id,
    required String workerId,
    required String categoryId,
    required String problemDescription,
  }) async {
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.insert(
        'request_drafts',
        {
          'id': id,
          'workerId': workerId,
          'categoryId': categoryId,
          'problemDescription': problemDescription,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> clearRequestDraft(String id) async {
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.delete('request_drafts', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }
}
