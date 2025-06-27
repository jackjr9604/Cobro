import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'create_credit_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientCreditsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String officeId;
  final String userId;

  const ClientCreditsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.officeId,
    required this.userId,
  });

  @override
  State<ClientCreditsScreen> createState() => _ClientCreditsScreenState();
}

class _ClientCreditsScreenState extends State<ClientCreditsScreen> {
  bool _showActiveCredits = true;
  bool _isLoading = true;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    _getOwnerId();
  }

  Future<void> _getOwnerId() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          final role = userData['role'] as String?;
          if (role == 'collector') {
            final createdBy = userData['createdBy'] as String?;
            setState(() {
              _ownerId = createdBy ?? widget.userId;
              _isLoading = false;
            });
            return;
          }
        }
      }
      setState(() {
        _ownerId = widget.userId;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error obteniendo ownerId: $e');
      setState(() {
        _ownerId = widget.userId;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCredit(String creditId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];

    if (role != 'owner') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No tienes permisos para eliminar créditos')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text('¿Estás seguro de eliminar este crédito?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_ownerId)
            .collection('offices')
            .doc(widget.officeId)
            .collection('clients')
            .doc(widget.clientId)
            .collection('credits')
            .doc(creditId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crédito eliminado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildCreditCard(DocumentSnapshot credit) {
    final data = credit.data() as Map<String, dynamic>;
    final isActive = data['isActive'] ?? false;
    final createdAt = data['createdAt']?.toDate();
    final nextPaymentIndex = data['nextPaymentIndex'] ?? 0;
    final paymentSchedule = List<String>.from(data['paymentSchedule'] ?? []);
    final nextPaymentDate =
        paymentSchedule.isNotEmpty && nextPaymentIndex < paymentSchedule.length
            ? DateTime.parse(paymentSchedule[nextPaymentIndex])
            : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Podrías añadir navegación a detalles del crédito aquí
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Crédito #${credit.id.substring(0, 6)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? Colors.green : Colors.grey, width: 1),
                    ),
                    child: Text(
                      isActive ? 'ACTIVO' : 'INACTIVO',
                      style: TextStyle(
                        color: isActive ? Colors.green[800] : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCreditInfoRow(
                'Valor del crédito:',
                '\$${NumberFormat('#,##0').format(data['credit'])}',
                Icons.attach_money,
                Colors.blue,
              ),
              _buildCreditInfoRow(
                'Interés:',
                '${data['interest']}% (Acumulado: \$${NumberFormat('#,##0').format(data['accumulatedInterest'] ?? 0)})',
                Icons.percent,
                Colors.orange,
              ),
              _buildCreditInfoRow(
                'Cuotas:',
                '${data['cuot']} (${data['method']})',
                Icons.calendar_view_week,
                Colors.purple,
              ),
              if (nextPaymentDate != null) ...[
                _buildCreditInfoRow(
                  'Próximo pago:',
                  DateFormat('dd/MM/yyyy').format(nextPaymentDate),
                  Icons.event_available,
                  Colors.green,
                ),
              ],
              _buildCreditInfoRow(
                'Total pagado:',
                '\$${NumberFormat('#,##0').format(data['totalPaid'] ?? 0)}',
                Icons.payment,
                Colors.teal,
              ),
              if (createdAt != null) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Creado: ${DateFormat('dd/MM/yyyy - HH:mm').format(createdAt)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (data['isActive'] == true) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (data['totalPaid'] ?? 0) / (data['credit'] ?? 1),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progreso: ${(data['totalPaid'] ?? 0) / (data['credit'] ?? 1) * 100}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[400]),
                    onPressed: () => _deleteCredit(credit.id),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            selected: _showActiveCredits,
            label: const Text('Activos'),
            onSelected: (selected) {
              setState(() {
                _showActiveCredits = selected;
                if (selected) {
                  _showActiveCredits = true;
                }
              });
            },
            selectedColor: Colors.green[100],
            checkmarkColor: Colors.green,
            labelStyle: TextStyle(
              color: _showActiveCredits ? Colors.green[800] : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: !_showActiveCredits,
            label: const Text('Inactivos'),
            onSelected: (selected) {
              setState(() {
                _showActiveCredits = !selected;
                if (selected) {
                  _showActiveCredits = false;
                }
              });
            },
            selectedColor: Colors.grey[200],
            checkmarkColor: Colors.grey[600],
            labelStyle: TextStyle(
              color: !_showActiveCredits ? Colors.grey[800] : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _ownerId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Créditos de ${widget.clientName}'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () {
              setState(() {
                _showActiveCredits = !_showActiveCredits;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(_ownerId)
                      .collection('offices')
                      .doc(widget.officeId)
                      .collection('clients')
                      .doc(widget.clientId)
                      .collection('credits')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Cargando créditos...', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No hay créditos registrados',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Puedes crear un nuevo crédito para este cliente',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                }

                final credits =
                    snapshot.data!.docs.where((doc) {
                      final isActive = doc['isActive'] ?? false;
                      return _showActiveCredits ? isActive : !isActive;
                    }).toList();

                if (credits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showActiveCredits ? Icons.check_circle_outline : Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showActiveCredits
                              ? 'No hay créditos activos'
                              : 'No hay créditos inactivos',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: credits.length,
                  itemBuilder: (context, index) => _buildCreditCard(credits[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => CreateCreditScreen(
                    clientId: widget.clientId,
                    officeId: widget.officeId,
                    userId: widget.userId,
                  ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
