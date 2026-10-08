import 'package:flutter/material.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text(
          'Could not open local storage. Restart the app and check the logs.',
        )),
      ),
    ));
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget{
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      home: DirectoryScreen(helper: helper),
    );
  }
}

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
  void initState(){
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
          _error =
              'Could not save guest. Your input is kept; retry Add/Save.';
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

    // Lock the form and actions while confirmation is open, too.
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Fall Festival Roster'),
    ),
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
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age (0–130)',
                ),
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
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!),
        ],
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
  );
}