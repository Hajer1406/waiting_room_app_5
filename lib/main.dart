import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/providers/queue_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file safely
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  // Initialize Supabase with environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      // Attempt anonymous sign-in in the background (non-blocking)
      Supabase.instance.client.auth.signInAnonymously().then((authResponse) {
        debugPrint('Signed in anonymously as user: ${authResponse.user?.id}');
      }).catchError((authError) {
        debugPrint('Anonymous auth skipped or disabled: $authError');
      });
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => QueueProvider(),
      child: const WaitingRoomApp(),
    ),
  );
}

class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WaitingRoomScreen(),
    );
  }
}

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitClient() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final error = await context.read<QueueProvider>().addClient(name);
      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur : $error',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        _controller.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QueueProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      hintText: 'Enter name',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _submitClient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitClient,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Queue Count Badge
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Clients in Queue: ${provider.clients.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Queue List
            Expanded(
              child: provider.clients.isEmpty
                  ? const Center(
                      child: Text(
                        'No one in queue yet...',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.clients.length,
                      itemBuilder: (context, index) {
                        final client = provider.clients[index];
                        final dateStr =
                            client.createdAt.toLocal().toString().split('.')[0];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          child: ListTile(
                            title: Text(
                              client.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      client.lat == null
                                          ? Icons.location_off
                                          : Icons.location_on,
                                      size: 14,
                                      color: client.lat == null
                                          ? Colors.grey.shade400
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      client.lat == null
                                          ? 'Location not captured'
                                          : '${client.lat!.toStringAsFixed(4)}, ${client.lng!.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: client.lat == null
                                            ? Colors.grey.shade500
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final err = await context
                                    .read<QueueProvider>()
                                    .removeClient(client.id);
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur suppression : $err'),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            // Next Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const Key('nextClientButton'),
                onPressed: provider.clients.isEmpty
                    ? null
                    : () async {
                        final err =
                            await context.read<QueueProvider>().nextClient();
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur : $err'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Next Client',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}