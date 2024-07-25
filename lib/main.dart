
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  bool isDragging = false;
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
                      onTap: () {
                        setState(() {
                          if (!pinnedApps.contains(app.packageName)) {
                            pinnedApps.add(app.packageName);
                            cachedApps[app.packageName] = CachedAppInfo.fromAppInfo(app);
                            _sortPinnedApps();
                            _savePinnedAppsAndCache();
                          }
                        });
                        Navigator.of(context).pop();
                      },
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
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(searchQuery)}';
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(),
          shareState: CustomTabsShareState.on,
          urlBarHidingEnabled: true,
          showTitle: true,
          closeButton: CustomTabsCloseButton(
            icon: CustomTabsCloseButtonIcons.back,
          ),
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

  void _sortPinnedApps() {
    pinnedApps.sort((a, b) {
      final appA = cachedApps[a];
      final appB = cachedApps[b];

      final nameA = appA?.name ?? '';
      final nameB = appB?.name ?? '';

      return nameA.compareTo(nameB);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: const Text('AppCore'),
        backgroundColor: Colors.black,
        titleTextStyle: const TextStyle(
            color: Color.fromARGB(255, 226, 225, 225),
            fontSize: 20,
            fontWeight: FontWeight.bold),
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
              child: Stack(
                children: [
                  GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 1 / 1.2,
                    ),
                    itemCount: pinnedApps
                        .where((packageName) {
                          final app = cachedApps[packageName];
                          return app != null && app.name
                              .toLowerCase()
                              .contains(searchQuery.toLowerCase());
                        })
                        .length,
                    itemBuilder: (context, index) {
                      final packageName = pinnedApps.where((packageName) {
                        final app = cachedApps[packageName];
                        return app != null && app.name
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase());
                      }).toList()[index];

                      final app = cachedApps[packageName];

                      if (app == null) {
                        return const SizedBox.shrink();
                      }

                      return Draggable<String>(
                        data: packageName,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _buildAppIcon(app, dragging: true),
                        ),
                        childWhenDragging: const SizedBox.shrink(),
                        onDragStarted: () =>
                            setState(() => isDragging = true),
                        onDragEnd: (details) {
                          setState(() => isDragging = false);
                        },
                        child: GestureDetector(
                          onTap: () => launchApp(packageName),
                          child: _buildAppIcon(app),
                        ),
                      );
                    },
                  ),
                  if (isDragging)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (details) => true,
                        onAcceptWithDetails: (details) {
                          setState(() {
                            pinnedApps.remove(details.data);
                            cachedApps.remove(details.data);
                            _sortPinnedApps();
                            _savePinnedAppsAndCache();
                            isDragging = false;
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            height: 100,
                            color: candidateData.isEmpty
                                ? Colors.black
                                : Colors.red,
                            child: Center(
                              child: Icon(
                                Icons.delete,
                                color: candidateData.isEmpty
                                    ? Colors.white
                                    : Colors.black,
                                size: 50,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
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

  Widget _buildAppIcon(CachedAppInfo app, {bool dragging = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        app.icon != null
            ? Image.memory(Uint8List.fromList(app.icon!), width: 50, height: 50)
            : const Icon(Icons.android, color: Colors.white, size: 50),
        const SizedBox(height: 5),
        Text(
          app.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: dragging ? 10 : 14,
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