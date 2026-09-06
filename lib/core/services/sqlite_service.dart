import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/category_model.dart';

class SqliteService {
  static final SqliteService instance = SqliteService._init();
  static Database? _database;

  SqliteService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cyns_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Categories table for offline browsing
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        isActive INTEGER NOT NULL
      )
    ''');

    // Recently viewed workers
    await db.execute('''
      CREATE TABLE recent_workers (
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
      CREATE TABLE request_drafts (
        id TEXT PRIMARY KEY,
        workerId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        problemDescription TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  // --- Category Cache Methods ---
  Future<void> cacheCategories(List<CategoryModel> categories) async {
    final db = await instance.database;
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
  }

  Future<List<CategoryModel>> getCachedCategories() async {
    final db = await instance.database;
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
  }

  // --- Recent Workers Methods ---
  Future<void> saveRecentWorker({
    required String workerId,
    required String name,
    required String profession,
    required double rating,
    required String profilePicUrl,
  }) async {
    final db = await instance.database;
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
  }

  Future<List<Map<String, dynamic>>> getRecentWorkers() async {
    final db = await instance.database;
    return await db.query(
      'recent_workers',
      orderBy: 'viewedAt DESC',
      limit: 10,
    );
  }

  // --- Offline Request Drafts ---
  Future<void> saveRequestDraft({
    required String id,
    required String workerId,
    required String categoryId,
    required String problemDescription,
  }) async {
    final db = await instance.database;
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
  }

  Future<void> clearRequestDraft(String id) async {
    final db = await instance.database;
    await db.delete('request_drafts', where: 'id = ?', whereArgs: [id]);
  }
}
