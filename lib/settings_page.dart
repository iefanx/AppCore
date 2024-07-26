import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as ctb;

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<String> _savedUrls = [];
  final List<String> _savedNotes = [];
  bool _showUrls = true;

  // Use a more descriptive name for clarity.
  final TextEditingController _newItemController = TextEditingController();

  // Use late initialization for controllers to improve readability.
  late _ItemSearchDelegate _searchDelegate;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _searchDelegate = _ItemSearchDelegate(_getCurrentItems); 
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  // Separate data loading and state updates for better structure.
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedUrls = prefs.getStringList('savedUrls') ?? [];
    final loadedNotes = prefs.getStringList('savedNotes') ?? [];
    setState(() {
      _savedUrls.addAll(loadedUrls); 
      _savedNotes.addAll(loadedNotes);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('savedUrls', _savedUrls);
    await prefs.setStringList('savedNotes', _savedNotes);
  }

  void _addItem(String item) {
    if (_showUrls && !item.startsWith('https://')) {
      item = 'https://$item';
    }
    setState(() {
      if (_showUrls) {
        _savedUrls.add(item);
      } else {
        _savedNotes.add(item);
      }
      _saveData();
    });
    // Update search delegate's data source
    _searchDelegate.updateItems(_getCurrentItems); 
  }

  void _removeItem(int index) {
    setState(() {
      if (_showUrls) {
        _savedUrls.removeAt(index);
      } else {
        _savedNotes.removeAt(index);
      }
      _saveData();
    });
    // Update search delegate's data source
    _searchDelegate.updateItems(_getCurrentItems); 
  }

  Future<void> _downloadBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final allData = prefs.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
      return map..addAll({key: prefs.get(key)});
    });
    final jsonString = jsonEncode(allData);
    await Share.share(jsonString, subject: 'App Data Backup');
  }

  Future<void> _restoreFromBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.single;
      final contents = utf8.decode(file.bytes!);
      final jsonData = jsonDecode(contents) as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      for (var entry in jsonData.entries) {
        if (entry.value is List) {
          await prefs.setStringList(entry.key, List<String>.from(entry.value));
        } else if (entry.value is String) {
          await prefs.setString(entry.key, entry.value);
        }
      }
      await _loadSavedData();
    }
  }

  // Use a getter for better readability and to avoid typos
  List<String> get _getCurrentItems => _showUrls ? _savedUrls : _savedNotes; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showUrls ? 'Saved URLs' : 'Saved Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _searchDelegate, 
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToggleBar(),
          Expanded(
            child: _getCurrentItems.isEmpty
                ? const Center(child: Text('No items found'))
                : ListView.builder(
              itemCount: _getCurrentItems.length,
              itemBuilder: (context, index) {
                final item = _getCurrentItems[index];
                return Dismissible(
                  key: Key(item),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeItem(index),
                  child: ListTile(
                    title: Text(item),
                    onTap: () {
                      if (_showUrls) {
                        _launchURL(item);
                      } else {
                        // Handle note tap 
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                onPressed: _downloadBackup,
                icon: Icons.cloud_download,
                label: 'Backup',
              ),
              _buildActionButton(
                onPressed: _restoreFromBackup,
                icon: Icons.restore,
                label: 'Restore',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      await ctb.launchUrl(
        Uri.parse(url),
        customTabsOptions: const ctb.CustomTabsOptions(
          shareState: ctb.CustomTabsShareState.on,
          urlBarHidingEnabled: true,
          showTitle: true,
          
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error launching URL: $e');
      }
    }
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildToggleBar() {
    return Container(
      color: Theme.of(context).primaryColor,
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => _showUrls = true),
              style: TextButton.styleFrom(
                backgroundColor: _showUrls ? Colors.white.withOpacity(0.2) : null,
              ),
              child: Text(
                'URLs',
                style: TextStyle(color: _showUrls ? Colors.white : Colors.white70),
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => _showUrls = false),
              style: TextButton.styleFrom(
                backgroundColor: !_showUrls ? Colors.white.withOpacity(0.2) : null,
              ),
              child: Text(
                'Notes',
                style: TextStyle(color: !_showUrls ? Colors.white : Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add ${_showUrls ? 'URL' : 'Note'}'),
          content: TextField(
            controller: _newItemController, // Use the correct controller
            decoration: InputDecoration(
              hintText: 'Enter ${_showUrls ? 'URL' : 'Note'}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_newItemController.text.isNotEmpty) { // Use the correct controller
                  _addItem(_newItemController.text);     // Use the correct controller
                  _newItemController.clear();              // Use the correct controller
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

// Update _ItemSearchDelegate to work with a data source
class _ItemSearchDelegate extends SearchDelegate<String> {
  List<String> _items;

  _ItemSearchDelegate(this._items);

  // Add a method to update the data source
  void updateItems(List<String> newItems) {
    _items = newItems;
    // Rebuild the search results
    
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = _items
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(results[index]),
          onTap: () {
            close(context, results[index]);
          },
        );
      },
    );
  }
}