import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;
import './login.dart';

/// Open Ticket System View
Future<void> openTicketSystem() async {
  Get.to(() => const TicketListPage());
}

class TicketCategory {
  final int id;
  final String name;
  final String description;

  TicketCategory({required this.id, required this.name, required this.description});

  factory TicketCategory.fromJson(Map<String, dynamic> json) {
    return TicketCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

class TicketListPage extends StatefulWidget {
  const TicketListPage({Key? key}) : super(key: key);

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends State<TicketListPage> {
  bool _isLoading = true;
  bool _isUnauthenticated = false;
  String _errorMsg = '';
  List<dynamic> _allTickets = [];
  List<dynamic> _filteredTickets = [];
  String _selectedStatus = 'all'; // 'all', '1' (Open), '2' (InProgress), '0' (Closed)
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _onlinePeerIds = {};

  int _countAll = 0;
  int _countOpen = 0;
  int _countInProgress = 0;
  int _countClosed = 0;

  @override
  void initState() {
    super.initState();
    platformFFI.registerEventHandler('callback_query_onlines', 'ticket_list_onlines', (evt) async {
      if (evt.containsKey('onlines') && evt['onlines'] is String) {
        final onlines = (evt['onlines'] as String).split(',');
        if (mounted) {
          setState(() {
            _onlinePeerIds.addAll(onlines.where((id) => id.isNotEmpty));
          });
        }
      }
    });
    _fetchTickets();
  }

  @override
  void dispose() {
    platformFFI.unregisterEventHandler('callback_query_onlines', 'ticket_list_onlines');
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _isUnauthenticated = false;
    });
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      if (token.isEmpty) {
        setState(() {
          _isUnauthenticated = true;
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$url/api/ticket/list?page=1&pageSize=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'api-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> list = [];
        if (data['data'] != null) {
          if (data['data'] is List) {
            list = data['data'];
          } else if (data['data']['list'] is List) {
            list = data['data']['list'];
          } else if (data['data']['data'] is List) {
            list = data['data']['data'];
          }
        }

        int cAll = list.length;
        int cOpen = 0;
        int cProgress = 0;
        int cClosed = 0;

        for (var item in list) {
          int s = item['status'] is int ? item['status'] : int.tryParse(item['status']?.toString() ?? '1') ?? 1;
          if (s == 1) {
            cOpen++;
          } else if (s == 2) {
            cProgress++;
          } else if (s == 0) {
            cClosed++;
          }
        }

        final peerIds = list
            .map((t) => (t['rustdesk_id'] ?? '').toString().trim())
            .where((id) => id.isNotEmpty)
            .toList();
        if (peerIds.isNotEmpty) {
          bind.queryOnlines(ids: peerIds);
        }

        setState(() {
          _allTickets = list;
          _countAll = cAll;
          _countOpen = cOpen;
          _countInProgress = cProgress;
          _countClosed = cClosed;
          _isUnauthenticated = false;
          _applyFilter();
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _isUnauthenticated = true;
        });
      } else {
        final err = json.decode(response.body);
        throw err['msg'] ?? err['error'] ?? 'Destek talepleri yüklenemedi.';
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    List<dynamic> result = List.from(_allTickets);

    if (_selectedStatus != 'all') {
      int targetStatus = int.tryParse(_selectedStatus) ?? 1;
      result = result.where((t) {
        int s = t['status'] is int ? t['status'] : int.tryParse(t['status']?.toString() ?? '1') ?? 1;
        return s == targetStatus;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) {
        final subject = (t['subject'] ?? '').toString().toLowerCase();
        final id = (t['id'] ?? '').toString();
        final rustdeskId = (t['rustdesk_id'] ?? '').toString().toLowerCase();
        return subject.contains(q) || id.contains(q) || rustdeskId.contains(q);
      }).toList();
    }

    setState(() {
      _filteredTickets = result;
    });
  }

  Widget _buildAuthGate(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AcilBir Destek Masası', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.teal.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.support_agent_rounded, size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AcilBir Destek Portalı',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Destek taleplerinizi görüntülemek, yeni talep açmak ve teknik ekibimizle anlık mesajlaşmak için lütfen hesabınıza giriş yapın.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildFeatureRow(Icons.flash_on_rounded, Colors.amber.shade700, 'Hızlı Uzaktan Destek', 'Tek tıkla teknisyen bağlantısı.'),
                          const SizedBox(height: 12),
                          _buildFeatureRow(Icons.chat_bubble_outline_rounded, Colors.blue.shade600, 'Canlı Durum & Sohbet', 'Talebinizin aşamalarını anlık takip edin.'),
                          const SizedBox(height: 12),
                          _buildFeatureRow(Icons.verified_user_outlined, Colors.green.shade600, 'Güvenli & Kayıtlı', 'Tüm işlemler uçtan uca şifreli ve kayıtlıdır.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Hesabıma Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final res = await loginDialog();
                          if (res == true || bind.mainGetLocalOption(key: 'access_token').isNotEmpty) {
                            _fetchTickets();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String title, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String statusKey,
  }) {
    final bool isSelected = _selectedStatus == statusKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = statusKey;
            _applyFilter();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).dividerColor.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 0:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'Açık';
      case 2:
        return 'İşlemde';
      case 0:
        return 'Kapalı';
      default:
        return 'Bilinmiyor';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 4:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 1:
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 4:
        return 'Acil';
      case 3:
        return 'Yüksek';
      case 2:
        return 'Normal';
      case 1:
      default:
        return 'Düşük';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnauthenticated || bind.mainGetLocalOption(key: 'access_token').isEmpty) {
      return _buildAuthGate(context);
    }
    final bool isAdmin = gFFI.userModel.isAdmin.value;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(isAdmin ? 'Yönetici Destek Masası' : 'Destek Taleplerim', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAdmin ? Colors.purple.withOpacity(0.15) : Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isAdmin ? 'YÖNETİCİ' : 'MÜŞTERİ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isAdmin ? Colors.purple : Colors.teal,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTickets,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.dialog<bool>(const TicketCreateDialog());
          if (result == true) {
            _fetchTickets();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Talep'),
      ),
      body: Column(
        children: [
          // Metric Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _buildMetricCard(
                  title: 'Tümü',
                  count: _countAll,
                  icon: Icons.confirmation_number_outlined,
                  color: Colors.deepOrange,
                  statusKey: 'all',
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  title: 'Açık',
                  count: _countOpen,
                  icon: Icons.headset_mic_outlined,
                  color: Colors.green,
                  statusKey: '1',
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  title: 'İşlemde',
                  count: _countInProgress,
                  icon: Icons.access_time_rounded,
                  color: Colors.blue,
                  statusKey: '2',
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  title: 'Kapalı',
                  count: _countClosed,
                  icon: Icons.check_circle_outline,
                  color: Colors.grey,
                  statusKey: '0',
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Konu veya Talep ID ile ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilter();
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilter();
                });
              },
            ),
          ),

          const Divider(height: 1),

          // List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMsg.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 40),
                            const SizedBox(height: 12),
                            Text(_errorMsg, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fetchTickets,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tekrar Dene'),
                            )
                          ],
                        ),
                      )
                    : _filteredTickets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Destek talebi bulunamadı.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredTickets.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final t = _filteredTickets[index];
                              final id = t['id'] ?? 0;
                              final subject = t['subject'] ?? 'Konu Belirtilmemiş';
                              final status = t['status'] is int ? t['status'] : int.tryParse(t['status']?.toString() ?? '1') ?? 1;
                              final priority = t['priority'] is int ? t['priority'] : int.tryParse(t['priority']?.toString() ?? '2') ?? 2;
                              final categoryName = t['category']?['name'] ?? t['category_name'] ?? 'Genel';
                              final clientUsername = t['user']?['username'] ?? t['username'];
                              final rustdeskId = (t['rustdesk_id'] ?? '').toString().trim();
                              final updatedAt = t['updated_at']?.toString().split('T').first ?? '';

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.4)),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final res = await Get.to(() => TicketDetailPage(ticketId: id));
                                    if (res == true) {
                                      _fetchTickets();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '#$id',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                subject,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _getStatusText(status),
                                                style: TextStyle(
                                                  color: _getStatusColor(status),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            if (clientUsername != null && clientUsername.toString().isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Müşteri: $clientUsername',
                                                  style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            if (rustdeskId.isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _onlinePeerIds.contains(rustdeskId) ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 7,
                                                      height: 7,
                                                      decoration: BoxDecoration(
                                                        color: _onlinePeerIds.contains(rustdeskId) ? Colors.green : Colors.grey,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Cihaz: $rustdeskId (${_onlinePeerIds.contains(rustdeskId) ? "Çevrimiçi" : "Çevrimdışı"})',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: _onlinePeerIds.contains(rustdeskId) ? Colors.green.shade800 : Colors.grey.shade700,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).dividerColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                categoryName,
                                                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getPriorityColor(priority).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Öncelik: ${_getPriorityText(priority)}',
                                                style: TextStyle(fontSize: 11, color: _getPriorityColor(priority), fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (updatedAt.isNotEmpty)
                                              Text(
                                                updatedAt,
                                                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                                              ),
                                          ],
                                        ),
                                        if (isAdmin && rustdeskId.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.teal.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                icon: const Icon(Icons.desktop_windows_rounded, size: 14),
                                                label: Text('⚡ Cihaza Bağlan ($rustdeskId)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                onPressed: () {
                                                  connect(context, rustdeskId);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

/// Create New Ticket Dialog
class TicketCreateDialog extends StatefulWidget {
  const TicketCreateDialog({Key? key}) : super(key: key);

  @override
  State<TicketCreateDialog> createState() => _TicketCreateDialogState();
}

class _TicketCreateDialogState extends State<TicketCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  final _rustdeskIdController = TextEditingController();
  final _targetUsernameController = TextEditingController();

  List<TicketCategory> _categories = [];
  int? _selectedCategoryId;
  int _selectedPriority = 2; // Normal
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    _rustdeskIdController.dispose();
    _targetUsernameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final myId = await bind.mainGetMyId();
      _rustdeskIdController.text = myId;

      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      final res = await http.get(
        Uri.parse('$url/api/ticket/category/all'),
        headers: {'Authorization': 'Bearer $token', 'api-token': token},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<dynamic> list = [];
        if (data['data'] is List) {
          list = data['data'];
        }
        final parsed = list.map((c) => TicketCategory.fromJson(c)).toList();
        setState(() {
          _categories = parsed;
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('Load categories error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');

      final Map<String, dynamic> body = {
        'subject': _subjectController.text.trim(),
        'content': _contentController.text.trim(),
        'rustdesk_id': _rustdeskIdController.text.trim(),
        'priority': _selectedPriority,
      };
      if (_selectedCategoryId != null && _selectedCategoryId! > 0) {
        body['category_id'] = _selectedCategoryId;
      }
      final targetUser = _targetUsernameController.text.trim();
      if (targetUser.isNotEmpty) {
        body['username'] = targetUser;
      }

      final response = await http.post(
        Uri.parse('$url/api/ticket/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'api-token': token,
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && (data['code'] == 0 || data['code'] == 200 || data['data'] != null)) {
        Get.back(result: true);
        showToast('Destek talebiniz başarıyla oluşturuldu.');
      } else {
        final serverMsg = data['msg'] ?? data['message'] ?? data['error'] ?? 'Talep oluşturulamadı.';
        throw serverMsg;
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = gFFI.userModel.isAdmin.value;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Yeni Destek Talebi',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('YÖNETİCİ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),

                // Admin Option: Open on behalf of Customer
                if (isAdmin) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.admin_panel_settings, size: 16, color: Colors.purple),
                            SizedBox(width: 6),
                            Text(
                              'Müşteri Adına Bilet Oluştur (Yönetici)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _targetUsernameController,
                          decoration: const InputDecoration(
                            labelText: 'Hedef Müşteri Kullanıcı Adı (İsteğe Bağlı)',
                            hintText: 'Boş bırakılırsa kendi adınıza bilet açılır',
                            prefixIcon: Icon(Icons.person_search, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Konu
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Konu *',
                    hintText: 'Örn: Bağlantı kesilme sorunu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Lütfen konu girin';
                    if (v.trim().length < 3) return 'Konu en az 3 karakter olmalıdır';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Kategori & Öncelik Row
                Row(
                  children: [
                    // Kategori
                    Expanded(
                      child: _isLoadingCategories
                          ? const Center(child: LinearProgressIndicator())
                          : DropdownButtonFormField<int>(
                              value: _selectedCategoryId,
                              decoration: const InputDecoration(
                                labelText: 'Kategori',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCategoryId = val;
                                });
                              },
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Öncelik
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Öncelik',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('0 - Düşük')),
                          DropdownMenuItem(value: 1, child: Text('1 - Normal')),
                          DropdownMenuItem(value: 2, child: Text('2 - Yüksek')),
                          DropdownMenuItem(value: 3, child: Text('3 - Acil')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPriority = val;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // AcilBir Cihaz ID
                TextFormField(
                  controller: _rustdeskIdController,
                  decoration: const InputDecoration(
                    labelText: 'AcilBir Cihaz ID',
                    hintText: 'Otomatik dolduruldu',
                    prefixIcon: Icon(Icons.devices, size: 20),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Mesaj / Açıklama
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Açıklama / Mesajınız *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.computer_rounded, size: 16),
                      label: const Text('Sistem Teşhisi Ekle', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final myId = await bind.mainGetMyId();
                        final osName = Platform.operatingSystem.toUpperCase();
                        final osVer = Platform.operatingSystemVersion;
                        final hostname = Platform.localHostname;
                        final cpuCount = Platform.numberOfProcessors;
                        final ver = await bind.mainGetVersion();

                        final diag = '\n\n📋 [Sistem Teşhis Özeti]\n'
                            '• Cihaz Adı: $hostname\n'
                            '• İşletim Sistemi: $osName ($osVer)\n'
                            '• CPU Çekirdek: $cpuCount\n'
                            '• AcilBir ID: $myId\n'
                            '• Sürüm: v$ver\n'
                            '------------------------';

                        setState(() {
                          _contentController.text = '${_contentController.text.trim()}$diag'.trim();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Yaşadığınız sorunu detaylıca açıklayınız...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Lütfen açıklama girin';
                    if (v.trim().length < 5) return 'Açıklama en az 5 karakter olmalıdır';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('İptal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Talebi Gönder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ticket Detail & Live Chat Page
class TicketDetailPage extends StatefulWidget {
  final int ticketId;
  const TicketDetailPage({Key? key, required this.ticketId}) : super(key: key);

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  bool _isLoading = true;
  String _errorMsg = '';
  Map<String, dynamic>? _ticketData;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingReply = false;
  bool _isClosing = false;
  Timer? _autoRefreshTimer;

  int _selectedRating = 5;
  final TextEditingController _ratingCommentController = TextEditingController();
  bool _isSubmittingRating = false;

  final List<String> _cannedResponses = [
    '⚡ Bağlantı isteği gönderildi, lütfen ekranınızdaki "Kabul Et" butonuna basınız.',
    '✅ İşlemleriniz başarıyla tamamlanmıştır, kontrol edebilirsiniz.',
    '🔄 Lütfen bilgisayarınızı yeniden başlatıp tekrar bağlanmayı deneyiniz.',
    '❓ Sorun devam ediyor mu? Ekran görüntüsü paylaşabilir misiniz?',
    '🔒 Talebiniz çözüme kavuşturulduğu için kapatılmıştır. İyi günler dileriz.',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    // Auto refresh chat every 5s for near-instant message updates
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading && !_isSendingReply) {
        _fetchDetail(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _replyController.dispose();
    _scrollController.dispose();
    _ratingCommentController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMsg = '';
      });
    }
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');
      final res = await http.get(
        Uri.parse('$url/api/ticket/detail/${widget.ticketId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'api-token': token,
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _ticketData = data['data'];
        });
        if (!silent) {
          _scrollToBottom();
        }
      } else {
        throw 'Talep detayı alınamadı.';
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSendingReply = true;
    });

    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');

      final body = {
        'ticket_id': widget.ticketId,
        'content': text,
      };

      final res = await http.post(
        Uri.parse('$url/api/ticket/reply'),
        headers: {
          'Authorization': 'Bearer $token',
          'api-token': token,
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (res.statusCode == 200) {
        _replyController.clear();
        await _fetchDetail(silent: true);
        _scrollToBottom();
      } else {
        final err = json.decode(res.body);
        throw err['msg'] ?? err['error'] ?? 'Yanıt gönderilemedi.';
      }
    } catch (e) {
      showToast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReply = false;
        });
      }
    }
  }

  Future<void> _closeTicket() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Talebi Kapat'),
        content: const Text('Bu destek talebini kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Kapat')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isClosing = true;
    });

    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');

      final res = await http.post(
        Uri.parse('$url/api/ticket/close'),
        headers: {
          'Authorization': 'Bearer $token',
          'api-token': token,
          'Content-Type': 'application/json',
        },
        body: json.encode({'id': widget.ticketId}),
      );

      if (res.statusCode == 200) {
        showToast('Destek talebi kapatıldı.');
        await _fetchDetail();
      } else {
        throw 'Talep kapatılamadı.';
      }
    } catch (e) {
      showToast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isClosing = false;
        });
      }
    }
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmittingRating = true;
    });
    try {
      final url = await bind.mainGetApiServer();
      final token = bind.mainGetLocalOption(key: 'access_token');

      final res = await http.post(
        Uri.parse('$url/api/ticket/rate'),
        headers: {
          'Authorization': 'Bearer $token',
          'api-token': token,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ticket_id': widget.ticketId,
          'rating': _selectedRating,
          'comment': _ratingCommentController.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        showToast('Geri bildiriminiz için teşekkür ederiz!');
        await _fetchDetail();
      } else {
        throw 'Puanlama gönderilemedi.';
      }
    } catch (e) {
      showToast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }

  Widget _buildChatBubble({
    required String senderName,
    required String content,
    required String time,
    required bool isMe,
    required bool isStaff,
  }) {
    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? theme.colorScheme.primary.withOpacity(0.15)
        : isStaff
            ? Colors.indigo.withOpacity(0.12)
            : theme.cardColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: isStaff ? Colors.indigo : Colors.grey.shade400,
              child: Icon(
                isStaff ? Icons.support_agent : Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 12),
                ),
                border: Border.all(
                  color: isMe
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : isStaff
                          ? Colors.indigo.withOpacity(0.3)
                          : theme.dividerColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isStaff ? Colors.indigo : theme.textTheme.titleSmall?.color,
                        ),
                      ),
                      if (isStaff) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'YETKİLİ',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    content,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _ticketData?['status'] ?? 1;
    final isClosed = status == 0;
    final currentUserId = UserModel.getLocalUserInfo()?['id'] ?? 0;
    final bool isAdmin = gFFI.userModel.isAdmin.value;
    final rating = _ticketData?['rating'] is int ? _ticketData!['rating'] : int.tryParse(_ticketData?['rating']?.toString() ?? '0') ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ticketData != null ? '#${_ticketData!['id']} - ${_ticketData!['subject']}' : 'Talep Detayı',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_ticketData != null && !isClosed)
            TextButton.icon(
              onPressed: _isClosing ? null : _closeTicket,
              icon: const Icon(Icons.check_circle_outline, color: Colors.orange, size: 18),
              label: const Text('Talebi Kapat', style: TextStyle(color: Colors.orange)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchDetail(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Ticket Info Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
                      ),
                      child: Row(
                        children: [
                          if (_ticketData?['user']?['username'] != null) ...[
                            Text(
                              'Müşteri: ${_ticketData!['user']['username']}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            'Kategori: ${_ticketData?['category']?['name'] ?? 'Genel'}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 12),
                          if (_ticketData?['rustdesk_id'] != null && _ticketData!['rustdesk_id'].toString().isNotEmpty)
                            Text(
                              'Cihaz ID: ${_ticketData!['rustdesk_id']}',
                              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          const Spacer(),
                          if (_ticketData?['rustdesk_id'] != null && _ticketData!['rustdesk_id'].toString().trim().isNotEmpty) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.desktop_windows_rounded, size: 16),
                              label: const Text('Uzaktan Bağlan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              onPressed: () {
                                final remoteId = _ticketData!['rustdesk_id'].toString().trim();
                                connect(context, remoteId);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isClosed ? Colors.grey.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isClosed ? 'KAPALI' : 'AÇIK / İŞLEMDE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isClosed ? Colors.grey : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Chat Scroll View
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          // First message (Ticket initial content)
                          _buildChatBubble(
                            senderName: _ticketData?['user']?['username'] ?? 'Müşteri',
                            content: _ticketData?['content'] ?? '',
                            time: _ticketData?['created_at']?.toString().split('T').first ?? '',
                            isMe: (_ticketData?['user_id'] == currentUserId),
                            isStaff: false,
                          ),

                          // Replies
                          if (_ticketData?['replies'] is List)
                            ...(_ticketData!['replies'] as List).map((r) {
                              final isStaff = (r['is_staff'] == true || r['is_staff'] == 1);
                              final senderName = isStaff ? 'Yetkili Destek' : (r['user']?['username'] ?? 'Müşteri');
                              final time = r['created_at']?.toString().split('T').first ?? '';
                              final isMe = (r['user_id'] == currentUserId);

                              return _buildChatBubble(
                                senderName: senderName,
                                content: r['content'] ?? '',
                                time: time,
                                isMe: isMe,
                                isStaff: isStaff,
                              );
                            }),

                          // Rating widget when ticket is closed
                          if (isClosed) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        rating > 0 ? 'Müşteri Değerlendirmesi ($rating / 5 Yıldız)' : 'Destek Deneyiminizi Puanlayın',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (rating > 0) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                          color: Colors.amber,
                                          size: 28,
                                        );
                                      }),
                                    ),
                                    if (_ticketData?['rating_comment'] != null && _ticketData!['rating_comment'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '"${_ticketData!['rating_comment']}"',
                                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey),
                                      ),
                                    ],
                                  ] else if (_ticketData?['user_id'] == currentUserId) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(5, (index) {
                                        final starVal = index + 1;
                                        return IconButton(
                                          icon: Icon(
                                            starVal <= _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                                            color: Colors.amber,
                                            size: 32,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _selectedRating = starVal;
                                            });
                                          },
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _ratingCommentController,
                                      decoration: InputDecoration(
                                        hintText: 'Görüş ve önerileriniz (isteğe bağlı)...',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: _isSubmittingRating
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.send_rounded, size: 16),
                                      label: const Text('Puanı Kaydet'),
                                      onPressed: _isSubmittingRating ? null : _submitRating,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Reply Box & Canned Responses
                    if (!isClosed)
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Canned Responses for Staff
                            if (isAdmin)
                              Container(
                                height: 38,
                                margin: const EdgeInsets.only(top: 6),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: _cannedResponses.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final text = _cannedResponses[index];
                                    return ActionChip(
                                      avatar: const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                                      label: Text(text, style: const TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        setState(() {
                                          _replyController.text = text;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Sistem Teşhis Bilgisi Ekle',
                                    icon: const Icon(Icons.computer_outlined, color: Colors.blueGrey),
                                    onPressed: () async {
                                      final myId = await bind.mainGetMyId();
                                      final osName = Platform.operatingSystem.toUpperCase();
                                      final osVer = Platform.operatingSystemVersion;
                                      final hostname = Platform.localHostname;
                                      final cpuCount = Platform.numberOfProcessors;

                                      final diag = '\n📋 [Sistem Teşhisi]\n'
                                          '• Cihaz: $hostname\n'
                                          '• İşletim Sistemi: $osName ($osVer)\n'
                                          '• CPU Çekirdek: $cpuCount\n'
                                          '• AcilBir ID: $myId\n';

                                      setState(() {
                                        _replyController.text = '${_replyController.text.trim()} $diag'.trim();
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _replyController,
                                      maxLines: 3,
                                      minLines: 1,
                                      decoration: InputDecoration(
                                        hintText: 'Yanıtınızı yazın...',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    icon: _isSendingReply
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.send_rounded),
                                    onPressed: _isSendingReply ? null : _sendReply,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey.withOpacity(0.1),
                        child: const Center(
                          child: Text(
                            'Bu destek talebi kapatılmıştır.',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
