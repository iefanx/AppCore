import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<String> _savedUrls = [];
  final List<String> _savedNotes = [];
  bool _showUrls = true;

  final TextEditingController _newItemController = TextEditingController();
  late _ItemSearchDelegate _searchDelegate;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _searchDelegate = _ItemSearchDelegate(_getCurrentItems);
    _handleIncomingShare();
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

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
    _searchDelegate.updateItems(_getCurrentItems);
  }

  Future<void> _downloadBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final allData = prefs.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
      return map..addAll({key: prefs.get(key)});
    });
    final jsonString = jsonEncode(allData);
    
    final directory = await getExternalStorageDirectory();
    final path = directory?.path ?? '';
    final filePath = '$path/backup.json';
    final file = File(filePath);
    
    await file.writeAsString(jsonString);
    
    await Share.shareXFiles([XFile(filePath)], text: 'App Data Backup');
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

    // Update the UI by reloading the data and rebuilding the widget tree
    setState(() {
      _savedUrls.clear(); // Clear existing data
      _savedNotes.clear();
      _loadSavedData(); // Reload from SharedPreferences
    });
  }
}

  Future<void> _handleIncomingShare() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final initialText = prefs.getString('shared_text');
    final initialUrl = prefs.getString('shared_url');

    if (initialText != null) {
      setState(() {
        _savedNotes.add(initialText);
        prefs.remove('shared_text');
      });
    }

    if (initialUrl != null) {
      setState(() {
        _savedUrls.add(initialUrl);
        prefs.remove('shared_url');
      });
    }
  }

  List<String> get _getCurrentItems => _showUrls ? _savedUrls : _savedNotes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showUrls ? 'Saved URLs' : 'Saved Notes'),
        titleTextStyle: const TextStyle(
            color: Color.fromARGB(255, 226, 225, 225),
            fontSize: 20,
            fontWeight: FontWeight.bold),
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
                          
                          titleTextStyle: const TextStyle(
                            color: Color.fromARGB(255, 226, 225, 225),
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
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
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: const CustomTabsOptions(
          
          shareState: CustomTabsShareState.on,
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
                textStyle: const TextStyle( fontWeight: FontWeight.bold, fontSize: 16),
              ),
              child: Text(
                'URLs',
                style: TextStyle(color: _showUrls ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold, fontSize: 16),
                
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => _showUrls = false),
              style: TextButton.styleFrom(
                backgroundColor: !_showUrls ? Colors.white.withOpacity(0.2) : null,
                textStyle: const TextStyle( fontWeight: FontWeight.bold, fontSize: 16),
              ),
              
              child: Text(
                'Notes',
                style: TextStyle(color: !_showUrls ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold, fontSize: 16),
                
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
            controller: _newItemController,
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
                if (_newItemController.text.isNotEmpty) {
                  _addItem(_newItemController.text);
                  _newItemController.clear();
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

class _ItemSearchDelegate extends SearchDelegate<String> {
  List<String> _items;

  _ItemSearchDelegate(this._items);

  void updateItems(List<String> newItems) {
    _items = newItems;
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
