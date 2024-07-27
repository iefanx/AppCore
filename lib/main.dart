import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'settings_page.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color.fromARGB(255, 224, 223, 223),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<String> pinnedApps = [];
  Map<String, CachedAppInfo> cachedApps = {};
  Map<String, AppInfo> installedApps = {};
  String searchQuery = "";
  bool _isLoadingInstalledApps = true;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadPinnedAppsAndCache();
    _loadInstalledAppsInBackground();
  }

  Future<void> _loadPinnedAppsAndCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        pinnedApps = prefs.getStringList('pinnedApps') ?? [];
        final cachedAppsJson = prefs.getString('cachedApps');
        if (cachedAppsJson != null) {
          final decodedApps = jsonDecode(cachedAppsJson) as Map<String, dynamic>;
          cachedApps = decodedApps.map((key, value) => MapEntry(key, CachedAppInfo.fromJson(value)));
        }
      });
    } catch (e) {
      debugPrint('Error loading pinned apps and cache: $e');
    }
  }

  Future<void> _savePinnedAppsAndCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pinnedApps', pinnedApps);
      final cachedAppsJson = jsonEncode(cachedApps.map((key, value) => MapEntry(key, value.toJson())));
      await prefs.setString('cachedApps', cachedAppsJson);
    } catch (e) {
      debugPrint('Error saving pinned apps and cache: $e');
    }
  }

  Future<void> _loadInstalledAppsInBackground() async {
    try {
      final apps = await InstalledApps.getInstalledApps(true, true);
      if (mounted) {
        setState(() {
          installedApps = {for (var app in apps) app.packageName: app};
          _updateCachedApps();
          _isLoadingInstalledApps = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading installed apps: $e');
      if (mounted) {
        setState(() {
          _isLoadingInstalledApps = false;
        });
      }
    }
  }

  void _updateCachedApps() {
    for (final packageName in pinnedApps) {
      if (installedApps.containsKey(packageName)) {
        cachedApps[packageName] = CachedAppInfo.fromAppInfo(installedApps[packageName]!);
      }
    }
    _savePinnedAppsAndCache();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoadingInstalledApps = true;
    });
    await _loadPinnedAppsAndCache();
    await _loadInstalledAppsInBackground();
  }

  Future<void> _showInstalledApps() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Installed Apps',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: Builder(builder: (context) {
              if (_isLoadingInstalledApps) {
                return const Center(child: CircularProgressIndicator());
              } else {
                final filteredApps = installedApps.values.where((app) =>
                    app.name.toLowerCase().contains(searchQuery.toLowerCase()));
                return ListView.builder(
                  itemCount: filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = filteredApps.toList()[index];
                    return ListTile(
                      leading: app.icon != null
                          ? Image.memory(app.icon!, width: 40, height: 40)
                          : const Icon(Icons.android, color: Colors.white),
                      title: Text(app.name,
                          style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: Icon(
                          pinnedApps.contains(app.packageName)
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            if (pinnedApps.contains(app.packageName)) {
                              pinnedApps.remove(app.packageName);
                              cachedApps.remove(app.packageName);
                            } else {
                              pinnedApps.add(app.packageName);
                              cachedApps[app.packageName] = CachedAppInfo.fromAppInfo(app);
                            }
                            _savePinnedAppsAndCache();
                          });
                        },
                      ),
                      onTap: () => launchApp(app.packageName),
                    );
                  },
                );
              }
            }),
          ),
        );
      },
    );
  }

  Future<void> launchApp(String packageName) async {
    try {
      await LaunchApp.openApp(androidPackageName: packageName);
    } catch (e) {
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error launching app: $e')),
        );
      }
    }
  }

  Future<void> _searchGoogle() async {
    final url = 'https://www.perplexity.ai/search?q=${Uri.encodeComponent(searchQuery)}';
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(),
          shareState: CustomTabsShareState.on,
          urlBarHidingEnabled: true,
          showTitle: true,
          
        ),
        
      );
    } catch (e) {
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error opening URL: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort pinned apps alphabetically
    pinnedApps.sort((a, b) => cachedApps[a]?.name.toLowerCase().compareTo(
          cachedApps[b]?.name.toLowerCase() ?? "",
        ) ?? 0);
        
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: const Text('AppCore'),
        backgroundColor: Colors.black,
        titleTextStyle: const TextStyle(
            color: Color.fromARGB(255, 226, 225, 225),
            fontSize: 20,
            fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.notes),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: TextField(
                onChanged: (query) {
                  setState(() {
                    searchQuery = query;
                  });
                },
                onSubmitted: (query) => _searchGoogle(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  hintText: 'Search Apps & Web...',
                  hintStyle: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold),
                  fillColor: const Color.fromARGB(255, 40, 39, 39),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9999),
                    borderSide: BorderSide.none,
                  ),
                  
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: _searchGoogle,
                    
                  ),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1 / 1.2,
                ),
                itemCount: pinnedApps.length, // No need to filter here anymore
                itemBuilder: (context, index) {
                  final packageName = pinnedApps[index]; // Directly access by index
                  final app = cachedApps[packageName];

                  if (app == null) {
                    return const SizedBox.shrink();
                  }

                  return GestureDetector(
                    onTap: () => launchApp(packageName),
                    child: _buildAppIcon(app, packageName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showInstalledApps,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildAppIcon(CachedAppInfo app, String packageName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        app.icon != null
            ? Image.memory(Uint8List.fromList(app.icon!), width: 50, height: 50)
            : const Icon(Icons.android, color: Colors.white, size: 50),
        const SizedBox(height: 5),
        Text(
          app.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class CachedAppInfo {
  final String name;
  final String packageName;
  final List<int>? icon;

  CachedAppInfo({required this.name, required this.packageName, this.icon});

  factory CachedAppInfo.fromAppInfo(AppInfo appInfo) {
    return CachedAppInfo(
      name: appInfo.name,
      packageName: appInfo.packageName,
      icon: appInfo.icon != null ? Uint8List.fromList(appInfo.icon!).toList() : null,
    );
  }

  factory CachedAppInfo.fromJson(Map<String, dynamic> json) {
    return CachedAppInfo(
      name: json['name'],
      packageName: json['packageName'],
      icon: json['icon'] != null ? List<int>.from(json['icon']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'packageName': packageName,
      'icon': icon,
    };
  }
}