import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stack) {
    debugPrint('Database initialization failed: $error\n$stack');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Check the logs before changing app data.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Card Catalogue',
    home: FolderScreen(helper: helper),
  );
}

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  List<Folder> _folders = [];
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _start() => setState(() {
    _busy = true;
    _error = null;
    _feedback = null;
  });

  Future<void> _read() async {
    final folders = await widget.helper.getFoldersWithCounts();
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _loaded = true;
      _error = null;
    });
  }

  Future<void> _reload(String failureMessage) async {
    try {
      await _read();
    } catch (error, stack) {
      debugPrint('Folder read failed: $error\n$stack');
      if (!mounted) return;
      setState(
        () => _error = '$failureMessage. Tap Refresh to retry the read.',
      );
    }
  }

  Future<void> _load() async {
    if (_busy) return;
    _start();
    try {
      await _reload('Could not read folders');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFolder() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    _start();
    try {
      int id;
      try {
        id = await widget.helper.insertFolder(
          Folder(
            name: name,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      } catch (error, stack) {
        debugPrint('Folder insert failed: $error\n$stack');
        if (!mounted) return;
        setState(
          () => _error =
              error is DatabaseException && error.isUniqueConstraintError()
              ? 'Folder "$name" already exists. Enter a different name.'
              : 'Could not create folder. Your input is kept; retry Create folder.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _name.clear();
        _formKey.currentState?.reset();
        _feedback = 'Created "$name" — folder ID $id.';
      });
      await _reload('Saved folder, but refresh failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete folder?'),
          content: Text(
            'Delete "${folder.name}" (ID ${folder.id}) and all its cards?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() {
        _error = null;
        _feedback = null;
      });
      int affected;
      try {
        affected = await widget.helper.deleteFolder(folder.id!);
      } catch (error, stack) {
        debugPrint('Folder delete failed: $error\n$stack');
        if (!mounted) return;
        setState(
          () => _error = 'Could not delete "${folder.name}". Retry Delete.',
        );
        return;
      }
      if (!mounted) return;
      setState(
        () => _feedback = affected == 1
            ? 'Deleted folder ID ${folder.id} (1 parent row). Its cards were deleted by cascade.'
            : affected == 0
            ? 'Folder ID ${folder.id} no longer exists.'
            : 'Unexpected delete result: $affected parent rows.',
      );
      await _reload(
        affected == 1
            ? 'Deleted folder, but refresh failed'
            : 'Could not reload folders',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder(Folder folder) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) =>
              CardScreen(helper: widget.helper, folder: folder),
        ),
      );
      if (!mounted) return;
      await _reload('Could not refresh folder counts');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGuests() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => DirectoryScreen(helper: widget.helper),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Card Catalogue')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _name,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Folder name'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter a folder name.' : null,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: _busy ? null : _addFolder,
              child: const Text('Create folder'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const Text('Refresh'),
            ),
            TextButton(
              onPressed: _busy ? null : _openGuests,
              child: const Text('Part 1 guests'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_feedback != null) Text(_feedback!),
        if (_error != null) Text(_error!),
        if (_loaded && _error != null)
          const Text('The list shows the last successful read.'),
        Text(_loaded ? 'Folders: ${_folders.length}' : 'Folders: unavailable'),
        if (_loaded && !_busy && _error == null && _folders.isEmpty)
          const Text('No folders yet.'),
        for (final folder in _folders)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${folder.name} — ID ${folder.id}'),
                  Text('Cards: ${folder.cardCount}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : () => _openFolder(folder),
                        child: const Text('Open'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _deleteFolder(folder),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class CardScreen extends StatefulWidget {
  const CardScreen({super.key, required this.helper, required this.folder});
  final DatabaseHelper helper;
  final Folder folder;

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _scroll = ScrollController();
  List<CardRecord> _cards = [];
  List<Folder> _folders = [];
  int? _editingId;
  int? _folderId;
  String? _suit;
  int _formRevision = 0;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _folderId = widget.folder.id;
    _load();
  }

  void _start() => setState(() {
    _busy = true;
    _error = null;
    _feedback = null;
  });

  Future<void> _read() async {
    final folders = await widget.helper.getFoldersWithCounts();
    if (!mounted) return;
    final cards = await widget.helper.getCards(widget.folder.id!);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _cards = cards;
      if (!folders.any((f) => f.id == _folderId)) {
        _folderId = null;
        _formRevision++;
      }
      _loaded = true;
      _error = null;
    });
  }

  Future<void> _reload(String failureMessage) async {
    try {
      await _read();
    } catch (error, stack) {
      debugPrint('Card read failed: $error\n$stack');
      if (!mounted) return;
      setState(
        () => _error = '$failureMessage. Tap Refresh to retry the read.',
      );
    }
  }

  Future<void> _load() async {
    if (_busy) return;
    _start();
    try {
      await _reload('Could not read cards');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _title.clear();
    _notes.clear();
    _editingId = null;
    _suit = null;
    _folderId = _folders.any((f) => f.id == widget.folder.id)
        ? widget.folder.id
        : null;
    _formRevision++;
  }

  void _edit(CardRecord card) {
    if (_busy) return;
    setState(() {
      _formKey.currentState?.reset();
      _editingId = card.id;
      _title.text = card.title;
      _notes.text = card.notes;
      _suit = card.suit;
      _folderId = _folders.any((f) => f.id == card.folderId)
          ? card.folderId
          : null;
      _formRevision++;
      _feedback = 'Editing card ID ${card.id}.';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final selectedId = _editingId;
    final card = CardRecord(
      id: selectedId,
      title: _title.text.trim(),
      suit: _suit!,
      notes: _notes.text.trim(),
      imageRef: null,
      folderId: _folderId!,
    );
    _start();
    try {
      int result;
      try {
        result = selectedId == null
            ? await widget.helper.insertCard(card)
            : await widget.helper.updateCard(card);
      } catch (error, stack) {
        debugPrint('Card save failed: $error\n$stack');
        if (!mounted) return;
        setState(
          () => _error =
              'Could not save card. Your input is kept. '
              'Refresh to check available folders, then retry Add/Save.',
        );
        return;
      }
      if (!mounted) return;
      if (selectedId != null && result != 1) {
        setState(
          () => _feedback = result == 0
              ? 'Card ID $selectedId no longer exists. Cancel edit to add a new card.'
              : 'Unexpected update result: $result rows.',
        );
        await _reload('Could not reload cards');
        return;
      }
      setState(() {
        _clearForm();
        _feedback = selectedId == null
            ? 'Added card ID $result to folder ID ${card.folderId}.'
            : 'Saved card ID $selectedId (1 row updated).';
      });
      await _reload('Saved, but refresh failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CardRecord card) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete card?'),
          content: Text('Delete "${card.title}" (ID ${card.id})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() {
        _error = null;
        _feedback = null;
      });
      int affected;
      try {
        affected = await widget.helper.deleteCard(card.id!);
      } catch (error, stack) {
        debugPrint('Card delete failed: $error\n$stack');
        if (!mounted) return;
        setState(
          () => _error = 'Could not delete card ID ${card.id}. Retry Delete.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        if (affected == 1 && _editingId == card.id) _clearForm();
        _feedback = affected == 1
            ? 'Deleted card ID ${card.id} (1 row deleted).'
            : affected == 0
            ? 'Card ID ${card.id} no longer exists.'
            : 'Unexpected delete result: $affected rows.';
      });
      await _reload(
        affected == 1
            ? 'Deleted, but refresh failed'
            : 'Could not reload cards',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _artwork(CardRecord card) {
    const symbols = {
      'Hearts': '♥',
      'Diamonds': '♦',
      'Clubs': '♣',
      'Spades': '♠',
    };

    return Semantics(
      label: '${card.suit} symbol',
      child: Text(
        symbols[card.suit] ?? '?',
        style: const TextStyle(fontSize: 36),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Folder ID: ${widget.folder.id}'),
          Text(_loaded ? 'Cards: ${_cards.length}' : 'Cards: unavailable'),
          OutlinedButton(
            onPressed: _busy ? null : _load,
            child: const Text('Refresh'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_feedback != null) Text(_feedback!),
          if (_error != null) Text(_error!),
          if (_loaded && _error != null)
            const Text('The list shows the last successful read.'),
          const SizedBox(height: 16),
          Text(_editingId == null ? 'Add card' : 'Edit card ID $_editingId'),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _title,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a card title.'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('suit-$_formRevision'),
                  initialValue: _suit,
                  decoration: const InputDecoration(labelText: 'Suit'),
                  items: CardRecord.suits
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _suit = value),
                  validator: (value) => CardRecord.suits.contains(value)
                      ? null
                      : 'Choose one suit.',
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('folder-$_formRevision'),
                  initialValue: _folderId,
                  decoration: const InputDecoration(labelText: 'Folder'),
                  items: _folders
                      .map(
                        (f) => DropdownMenuItem(
                          value: f.id,
                          child: Text('${f.name} (ID ${f.id})'),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _folderId = value),
                  validator: (value) =>
                      value != null && _folders.any((f) => f.id == value)
                      ? null
                      : 'Choose an existing folder.',
                ),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: Text(_editingId == null ? 'Add' : 'Save'),
              ),
              TextButton(
                onPressed: _busy || _editingId == null
                    ? null
                    : () => setState(() {
                        _clearForm();
                        _feedback = 'Edit canceled; no changes saved.';
                      }),
                child: const Text('Cancel edit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loaded && !_busy && _error == null && _cards.isEmpty)
            const Text('No cards in this folder yet.'),
          for (final card in _cards)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _artwork(card),
                    Text('${card.title} — ID ${card.id}'),
                    Text('Suit: ${card.suit} | Folder ID: ${card.folderId}'),
                    if (card.notes.isNotEmpty) Text('Notes: ${card.notes}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _edit(card),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _delete(card),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// Guest screen.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  int? _count;
  int? _selectedId;
  bool _busy = false;
  bool _hasLoaded = false;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _readRows() async {
    final rows = await widget.helper.queryAllRows();
    if (!mounted) return;

    final count = await widget.helper.queryRowCount();
    if (!mounted) return;

    setState(() {
      _rows = rows;
      _count = count;
      _hasLoaded = true;
      _error = null;
    });
  }

  void _log(String action, Object error, StackTrace stack) {
    debugPrint('$action: $error\n$stack');
  }

  Future<void> _load() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _readRows();
    } catch (error, stack) {
      _log('Read failed', error, stack);
      if (!mounted) return;

      setState(() {
        _error = 'Could not read guests. Tap Refresh to retry.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _selectedId = null;
    _nameController.clear();
    _ageController.clear();
    _formKey.currentState?.reset();
  }

  void _edit(Map<String, dynamic> row) {
    if (_busy) return;

    setState(() {
      _formKey.currentState?.reset();
      _selectedId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _feedback = 'Editing guest ID $_selectedId.';
    });
  }

  Future<void> _refreshAfterWrite(String failureMessage) async {
    try {
      await _readRows();
    } catch (error, stack) {
      _log('Refresh after write failed', error, stack);
      if (!mounted) return;

      setState(() {
        _error = '$failureMessage. Tap Refresh to retry the read.';
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim())!;
    final selectedId = _selectedId;

    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });

    try {
      int result;

      try {
        if (selectedId == null) {
          result = await widget.helper.insert({
            DatabaseHelper.columnName: name,
            DatabaseHelper.columnAge: age,
          });
        } else {
          result = await widget.helper.update({
            DatabaseHelper.columnId: selectedId,
            DatabaseHelper.columnName: name,
            DatabaseHelper.columnAge: age,
          });
        }
      } catch (error, stack) {
        _log('Save failed', error, stack);
        if (!mounted) return;

        setState(() {
          _error = 'Could not save guest. Your input is kept; retry Add/Save.';
        });
        return;
      }

      if (!mounted) return;

      if (selectedId != null && result != 1) {
        setState(() {
          _feedback = result == 0
              ? 'Guest ID $selectedId no longer exists. '
                    'Cancel edit to add a new guest.'
              : 'Unexpected update result: $result affected rows. '
                    'Tap Refresh.';
        });

        await _refreshAfterWrite('Could not reload guests');
        return;
      }

      setState(() {
        _clearForm();
        _feedback = selectedId == null
            ? 'Added guest with ID $result.'
            : 'Saved guest ID $selectedId ($result row updated).';
      });

      await _refreshAfterWrite('Saved, but refresh failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;

    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;

    setState(() => _busy = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete guest?'),
          content: Text('Delete ID $id: $name?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      setState(() {
        _error = null;
        _feedback = null;
      });

      int deleted;

      try {
        deleted = await widget.helper.delete(id);
      } catch (error, stack) {
        _log('Delete failed', error, stack);
        if (!mounted) return;

        setState(() {
          _error = 'Could not delete ID $id. Retry Delete.';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        if (deleted == 1) {
          if (_selectedId == id) _clearForm();
          _feedback = 'Deleted guest ID $id ($deleted row deleted).';
        } else {
          _feedback = deleted == 0
              ? 'Guest ID $id no longer exists.'
              : 'Unexpected delete result: $deleted affected rows. '
                    'Tap Refresh.';
        }
      });

      await _refreshAfterWrite(
        deleted == 1
            ? 'Deleted, but refresh failed'
            : 'Could not reload guests',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Fall Festival Roster')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Enter a name.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ageController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age (0–130)'),
                  validator: (value) {
                    final age = int.tryParse((value ?? '').trim());

                    if (age == null) {
                      return 'Enter a whole-number age.';
                    }

                    if (age < 0 || age > 130) {
                      return 'Age must be from 0 through 130.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: Text(_selectedId == null ? 'Add' : 'Save'),
              ),
              TextButton(
                onPressed: _busy || _selectedId == null
                    ? null
                    : () => setState(_clearForm),
                child: const Text('Cancel edit'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _load,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _count == null
                ? 'Record count: unavailable'
                : 'Record count: $_count',
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Text(_feedback!),
          ],
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
          const SizedBox(height: 16),
          if (!_busy && _error == null && _hasLoaded && _rows.isEmpty)
            const Text('No festival guests yet'),
          if (_hasLoaded && _error != null)
            const Text(
              'The list and count below are from the last successful read.',
            ),
          for (final row in _rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${row[DatabaseHelper.columnId]}'),
                    Text('Name: ${row[DatabaseHelper.columnName]}'),
                    Text('Age: ${row[DatabaseHelper.columnAge]}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _edit(row),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _delete(row),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
