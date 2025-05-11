import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

enum OfficeFilter { all, assigned, unassigned }

class OfficesDetailScreen extends StatefulWidget {
  final OfficeFilter filter;
  const OfficesDetailScreen({super.key, required this.filter});

  @override
  State<OfficesDetailScreen> createState() => _OfficesDetailScreenState();
}

class _OfficesDetailScreenState extends State<OfficesDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchOwnerUid = '';

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }

  String _format(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/"
      "${d.month.toString().padLeft(2, '0')}/"
      "${d.year}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Oficinas - ${widget.filter.name}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Filtrar por UID dueño',
                        ),
                        onChanged:
                            (v) => setState(() => _searchOwnerUid = v.trim()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.date_range),
                      onPressed: _pickDateRange,
                    ),
                  ],
                ),
                if (_startDate != null && _endDate != null)
                  Text(
                    'Rango: ${_format(_startDate!)} - ${_format(_endDate!)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('offices').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snap.data!.docs;

          // Filtrar por asignadas / no asignadas
          docs =
              docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final hasField = data.containsKey('createdBy');
                final isNull = data['createdBy'] == null;
                if (widget.filter == OfficeFilter.assigned) {
                  return hasField && !isNull;
                }
                if (widget.filter == OfficeFilter.unassigned) {
                  return !hasField || isNull;
                }
                return true; // all
              }).toList();

          // Filtrar por rango de fechas
          if (_startDate != null && _endDate != null) {
            docs =
                docs.where((d) {
                  final ts = d['createdAt'] as Timestamp;
                  final dt = ts.toDate();
                  return dt.isAfter(
                        _startDate!.subtract(const Duration(days: 1)),
                      ) &&
                      dt.isBefore(_endDate!.add(const Duration(days: 1)));
                }).toList();
          }

          // Filtrar por UID dueño
          if (_searchOwnerUid.isNotEmpty) {
            docs =
                docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final sb = data['createdBy'] as String?;
                  return sb != null && sb.contains(_searchOwnerUid);
                }).toList();
          }

          if (docs.isEmpty) {
            return const Center(child: Text('No hay oficinas.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final officeName = data['name'] ?? 'Sin nombre';
              final createdAt = (data['createdAt'] as Timestamp).toDate();
              final ownerUid = data['createdBy'] as String?;

              if (ownerUid == null) {
                // Oficina sin dueño
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _copyable('Oficina', officeName),
                        _copyable('Creada', _format(createdAt)),
                        _copyable('Dueño UID', '-'),
                        _copyable('Dueño Nombre', '-'),
                      ],
                    ),
                  ),
                );
              } else {
                // Oficina con dueño
                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(ownerUid).get(),
                  builder: (context, userSnap) {
                    String ownerName = '-';
                    if (userSnap.hasData && userSnap.data!.exists) {
                      final userData =
                          userSnap.data!.data() as Map<String, dynamic>?;
                      if (userData != null) {
                        ownerName = userData['displayName'] ?? '-';
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _copyable('Oficina', officeName),
                            _copyable('Creada', _format(createdAt)),
                            _copyable('Dueño UID', ownerUid),
                            _copyable('Dueño Nombre', ownerName),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _copyable(String label, String value) {
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label copiado')));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('$label: $value'),
      ),
    );
  }
}
