import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/happs_model.dart';
import '../repositories/happs_repositories.dart';

class HappsListPage extends StatefulWidget {
  const HappsListPage({super.key});

  @override
  State<HappsListPage> createState() => _HappsListPageState();
}

class _HappsListPageState extends State<HappsListPage> {
  final _happRepo = HappRepository();
  final _auth = FirebaseAuth.instance;
  List<HappsModel> _happs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHapps();
  }

  Future<void> _loadHapps() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final happs = await _happRepo.getHappsForUser(uid);
    if (!mounted) return;
    setState(() {
      _happs = happs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6FF),
        elevation: 0,
        title: const Text(
          'My Happs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _happs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_outlined, size: 72, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No happs yet',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _happs.length,
                  itemBuilder: (context, index) {
                    final happ = _happs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: const Icon(
                            Icons.event,
                            color: Colors.deepPurple,
                          ),
                        ),
                        title: Text(
                          happ.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${happ.category} · ${DateFormat('MMM d, h:mm a').format(happ.when)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Text(
                          '${happ.participants.length} joined',
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}