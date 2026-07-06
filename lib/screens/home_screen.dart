import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/thread_card.dart';
import '../services/api_service.dart';
import '../services/http_client.dart';
import '../models/thread.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;
  List<Thread> _threads = [];
  bool _isLoading = true;
  bool _needLogin = false;

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() {
      _isLoading = true;
      _needLogin = false;
    });
    try {
      final apiService = ApiService(S1HttpClient.instance);

      var threads = await apiService.getThreadList('4');
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    } on LoginRequiredException {
      setState(() {
        _needLogin = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stage1st'),
        actions: [
          if (!isLoggedIn)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Login'),
            ),
        ],
      ),
      body: _currentTab == 0
          ? _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _needLogin
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('请先登录',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/login'),
                            icon: const Icon(Icons.login),
                            label: const Text('去登录'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadThreads,
                      child: ListView.builder(
                        itemCount: _threads.length,
                        itemBuilder: (context, index) =>
                            ThreadCard(thread: _threads[index]),
                      ),
                    )
          : _currentTab == 1
              ? const Center(child: Text('Search'))
              : _currentTab == 2
                  ? const Center(child: Text('Messages'))
                  : const ProfileScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum), label: 'Forum'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
