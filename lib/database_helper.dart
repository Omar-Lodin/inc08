import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MyDatabase.db";
  static const _databaseVersion = 2;
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';
  late Database _db;
// this opens the database (and creates it if it doesn't exist)
  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _onCreate(db, version);
        await _createCatalogueTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCatalogueTables(db);
      },
    );
  }

// SQL code to create the database table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE $table (
$columnId INTEGER PRIMARY KEY,
$columnName TEXT NOT NULL,
$columnAge INTEGER NOT NULL
)
''');
  }

// Helper methods
// Inserts a row in the database where each key in the
//Map is a column name
// and the value is the column value. The return value
//is the id of the
// inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

// All of the rows are returned as a list of maps, where each map is
// a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table);
  }

// All of the methods (insert, query, update, delete) can also be done using
// raw SQL commands. This method uses a raw query to give the row count.
  Future<int> queryRowCount() async {
    final results = await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(results) ?? 0;
  }

// We are assuming here that the id column in the map is set. The other
// column values will be used to update the row.
  Future<int> update(Map<String, dynamic> row) async {
    int id = row[columnId];
    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

// Deletes the row specified by the id. The number of affected rows is
// returned. This should be 1 as long as the row exists.
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<void> _createCatalogueTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS folders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  suit TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  image_ref TEXT,
  folder_id INTEGER NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
)
''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cards_folder_id ON cards(folder_id)');
  }

  Future<int> insertFolder(Folder folder) => _db.insert('folders', folder.toMap());

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
FROM folders f LEFT JOIN cards c ON c.folder_id = f.id
GROUP BY f.id, f.name, f.created_at
ORDER BY f.name COLLATE NOCASE ASC, f.id ASC
''');
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _db.query('cards', where: 'folder_id = ?',
      whereArgs: [folderId], orderBy: 'title COLLATE NOCASE ASC, id ASC');
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> insertCard(CardRecord card) => _db.insert('cards', card.toMap());

  Future<int> updateCard(CardRecord card) {
    if (card.id == null) throw ArgumentError('An update requires a card ID.');
    final values = card.toMap()..remove('id');
    return _db.update('cards', values, where: 'id = ?', whereArgs: [card.id]);
  }

  Future<int> deleteCard(int id) =>
      _db.delete('cards', where: 'id = ?', whereArgs: [id]);

  Future<int> deleteFolder(int id) =>
      _db.delete('folders', where: 'id = ?', whereArgs: [id]);

  // Read-only database diagnostics, including orphaned cards.
  Future<Map<String, Object?>> getDiagnostics() async {
    return {
      'database': _databaseName,
      'user_version': await _db.rawQuery('PRAGMA user_version'),
      'foreign_keys': await _db.rawQuery('PRAGMA foreign_keys'),
      'foreign_key_list(cards)': await _db.rawQuery('PRAGMA foreign_key_list(cards)'),
      'index_list(cards)': await _db.rawQuery('PRAGMA index_list(cards)'),
      'foreign_key_check': await _db.rawQuery('PRAGMA foreign_key_check'),
      'tables_and_card_index': await _db.rawQuery(
        "SELECT type, name, sql FROM sqlite_master WHERE name IN "
        "('my_table', 'folders', 'cards', 'idx_cards_folder_id') ORDER BY name"),
      'part1_rows': await _db.query(table, orderBy: '$columnId ASC'),
      'part1_count': await queryRowCount(),
      'folders': await _db.query('folders', orderBy: 'id ASC'),
      'cards': await _db.query('cards', orderBy: 'id ASC'),
      'orphan_cards': await _db.rawQuery(
        'SELECT c.* FROM cards c LEFT JOIN folders f ON f.id = c.folder_id WHERE f.id IS NULL'),
    };
  }
}

class Folder {
  const Folder({this.id, required this.name, required this.createdAt, this.cardCount = 0});
  final int? id;
  final String name;
  final String createdAt;
  final int cardCount;

  factory Folder.fromMap(Map<String, dynamic> map) => Folder(
    id: map['id'] as int,
    name: map['name'] as String,
    createdAt: map['created_at'] as String,
    cardCount: (map['card_count'] as int?) ?? 0,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'created_at': createdAt,
  };
}

class CardRecord {
  const CardRecord({this.id, required this.title, required this.suit,
    this.notes = '', this.imageRef, required this.folderId});
  static const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  factory CardRecord.fromMap(Map<String, dynamic> map) => CardRecord(
    id: map['id'] as int,
    title: map['title'] as String,
    suit: map['suit'] as String,
    notes: map['notes'] as String,
    imageRef: map['image_ref'] as String?,
    folderId: map['folder_id'] as int,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'suit': suit,
    'notes': notes,
    'image_ref': imageRef,
    'folder_id': folderId,
  };
}
