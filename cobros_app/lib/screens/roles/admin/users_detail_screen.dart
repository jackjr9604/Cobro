import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

enum UserFilter { all, admin, owner, collector, noRole, active, inactive }

class UsersDetailScreen extends StatefulWidget {
  final UserFilter filter;
  const UsersDetailScreen({super.key, required this.filter});

  @override
  State<UsersDetailScreen> createState() => _UsersDetailScreenState();
}

class _UsersDetailScreenState extends State<UsersDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchText = '';
  bool _ascending = true;
  String _roleFilter = 'Todos';

  List<String> roles = ['Todos', 'admin', 'owner', 'collector', 'Sin rol'];

  Query _buildQuery() {
    Query col = _firestore.collection('users');

    switch (widget.filter) {
      case UserFilter.active:
        col = col.where('isActive', isEqualTo: true);
        break;
      case UserFilter.inactive:
        col = col.where('isActive', isEqualTo: false);
        break;
      case UserFilter.all:
      case UserFilter.admin:
      case UserFilter.owner:
      case UserFilter.collector:
      case UserFilter.noRole:
        // roles se manejan con _roleFilter ahora
        break;
    }

    if (_roleFilter == 'Sin rol') {
      col = col.where('role', isNull: true);
    } else if (_roleFilter != 'Todos') {
      col = col.where('role', isEqualTo: _roleFilter);
    }

    return col;
  }

  @override
  Widget build(BuildContext context) {
    // Actualizamos _roleFilter según el filtro recibido
    if (_roleFilter == 'Todos') {
      switch (widget.filter) {
        case UserFilter.admin:
          _roleFilter = 'admin';
          break;
        case UserFilter.owner:
          _roleFilter = 'owner';
          break;
        case UserFilter.collector:
          _roleFilter = 'collector';
          break;
        case UserFilter.noRole:
          _roleFilter = 'Sin rol';
          break;
        case UserFilter.active:
        case UserFilter.inactive:
          // Aquí no hay un cambio en _roleFilter, ya que depende de `isActive`
          break;
        default:
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Usuarios - ${widget.filter.name.capitalize()}',
        ), // Para mostrar bien el nombre del filtro
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(105),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Filtrar por nombre/email/UID',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          isDense: true,
                        ),
                        onChanged:
                            (v) => setState(
                              () => _searchText = v.trim().toLowerCase(),
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _ascending ? Icons.arrow_downward : Icons.arrow_upward,
                      ),
                      onPressed: () => setState(() => _ascending = !_ascending),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Rol:'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _roleFilter,
                      items:
                          roles
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _roleFilter = v!),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snap.data!.docs;

          // Filtro por búsqueda
          if (_searchText.isNotEmpty) {
            docs =
                docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['displayName'] ?? '').toLowerCase();
                  final email = (data['email'] ?? '').toLowerCase();
                  final uid = d.id.toLowerCase();
                  return name.contains(_searchText) ||
                      email.contains(_searchText) ||
                      uid.contains(_searchText);
                }).toList();
          }

          // Orden
          docs.sort((a, b) {
            final n1 = (a['displayName'] ?? '').toLowerCase();
            final n2 = (b['displayName'] ?? '').toLowerCase();
            return _ascending ? n1.compareTo(n2) : n2.compareTo(n1);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No hay usuarios.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final uid = docs[i].id;
              final name = d['displayName'] ?? 'Sin nombre';
              final email = d['email'] ?? 'Sin email';
              final role = d['role'] ?? 'Sin rol';
              final active = d['isActive'] == true ? 'Sí' : 'No';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCopyable('Nombre', name),
                      _buildCopyable('Email', email),
                      _buildCopyable('Rol', role),
                      _buildCopyable('Activo', active),
                      _buildCopyable('UID', uid),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCopyable(String label, String value) {
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

extension StringCapitalize on String {
  String capitalize() {
    if (this.isEmpty) {
      return this; // Si la cadena está vacía, simplemente la devuelve
    }
    return '${this[0].toUpperCase()}${this.substring(1).toLowerCase()}'; // Capitaliza solo la primera letra
  }
}
