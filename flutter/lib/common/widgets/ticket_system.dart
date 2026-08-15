import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common.dart';
import '../utils/http_service.dart' as http;

Future<void> openTicketSystem() async {
  Get.to(() => const TicketListPage());
}

class TicketListPage extends StatefulWidget {
  const TicketListPage({Key? key}) : super(key: key);

  @override
  _TicketListPageState createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage> {
  bool isLoading = true;
  List<dynamic> tickets = [];
  String errorMsg = '';

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      isLoading = true;
      errorMsg = '';
    });
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      final response = await http.get(
        Uri.parse('$url/api/ticket/list?page=1&pageSize=50'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data']['data'] != null) {
          setState(() {
            tickets = data['data']['data'];
          });
        }
      } else {
        throw 'Failed to load tickets';
      }
    } catch (e) {
      setState(() {
        errorMsg = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destek Taleplerim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTickets,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Get.dialog<bool>(const TicketCreateDialog());
              if (result == true) {
                _fetchTickets();
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg.isNotEmpty
              ? Center(child: Text(errorMsg, style: const TextStyle(color: Colors.red)))
              : tickets.isEmpty
                  ? const Center(child: Text('Henüz destek talebiniz bulunmuyor.'))
                  : ListView.builder(
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final t = tickets[index];
                        return ListTile(
                          title: Text(t['subject'] ?? 'Konu Yok'),
                          subtitle: Text('Durum: ${t['status']} | Kategori: ${t['category_name']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Get.to(() => TicketDetailPage(ticketId: t['id']));
                          },
                        );
                      },
                    ),
    );
  }
}

class TicketCreateDialog extends StatefulWidget {
  const TicketCreateDialog({Key? key}) : super(key: key);

  @override
  _TicketCreateDialogState createState() => _TicketCreateDialogState();
}

class _TicketCreateDialogState extends State<TicketCreateDialog> {
  final subjectController = TextEditingController();
  final descController = TextEditingController();
  bool isLoading = false;

  void _submit() async {
    if (subjectController.text.trim().isEmpty || descController.text.trim().isEmpty) return;

    setState(() => isLoading = true);
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      final response = await http.post(
        Uri.parse('$url/api/ticket/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'subject': subjectController.text.trim(),
          'description': descController.text.trim(),
          'priority': 2, // Normal
          'category_id': 1, // Default
        }),
      );
      if (response.statusCode == 200) {
        Get.back(result: true);
      } else {
        throw 'Failed to create ticket';
      }
    } catch (e) {
      Get.snackbar('Hata', e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Destek Talebi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Konu'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Açıklama'),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('İptal')),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading ? const CircularProgressIndicator() : const Text('Gönder'),
        ),
      ],
    );
  }
}

class TicketDetailPage extends StatefulWidget {
  final int ticketId;
  const TicketDetailPage({Key? key, required this.ticketId}) : super(key: key);

  @override
  _TicketDetailPageState createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  bool isLoading = true;
  Map<String, dynamic>? ticket;
  List<dynamic> replies = [];
  final replyController = TextEditingController();
  bool isReplying = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => isLoading = true);
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      final response = await http.get(
        Uri.parse('$url/api/ticket/detail/${widget.ticketId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          setState(() {
            ticket = data['data'];
            replies = data['data']['replies'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    if (replyController.text.trim().isEmpty) return;
    setState(() => isReplying = true);
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      final response = await http.post(
        Uri.parse('$url/api/ticket/reply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ticket_id': widget.ticketId,
          'message': replyController.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        replyController.clear();
        _fetchDetail(); // Refresh to see the new reply
      }
    } catch (e) {
      Get.snackbar('Hata', e.toString());
    } finally {
      if (mounted) setState(() => isReplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ticket != null ? ticket!['subject'] : 'Yükleniyor...')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ticket == null
              ? const Center(child: Text('Bulunamadı'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(ticket!['description'] ?? '', style: const TextStyle(fontSize: 16)),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          final r = replies[index];
                          final isMe = r['is_staff'] == false;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(r['message'] ?? ''),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyController,
                              decoration: const InputDecoration(hintText: 'Mesajınız...'),
                            ),
                          ),
                          IconButton(
                            icon: isReplying ? const CircularProgressIndicator() : const Icon(Icons.send),
                            onPressed: isReplying ? null : _sendReply,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
