import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'credit_inactive_detail_screen.dart';

class InactiveCreditsScreen extends StatefulWidget {
  const InactiveCreditsScreen({super.key});

  @override
  State<InactiveCreditsScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends State<InactiveCreditsScreen> {
  final Map<String, int> orderMap = {};
  final Map<String, TextEditingController> controllers = {};

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Usuario no autenticado')));
    }

    final uid = currentUser.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Créditos Cerrados')),

      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('credits')
                .where('createdBy', isEqualTo: uid)
                .where('isActive', isEqualTo: false)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes créditos cerrados.'));
          }

          final credits = snapshot.data!.docs;

          for (var i = 0; i < credits.length; i++) {
            final id = credits[i].id;
            orderMap.putIfAbsent(id, () => i + 1);
            controllers.putIfAbsent(
              id,
              () => TextEditingController(text: orderMap[id]!.toString()),
            );
          }

          credits.sort((a, b) => orderMap[a.id]!.compareTo(orderMap[b.id]!));

          return ListView.builder(
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final credit = credits[index];
              final data = credit.data() as Map<String, dynamic>;
              final createdAt = data['createdAt']?.toDate();
              final creditValue = (data['credit'] as num).toDouble();
              final interestPercent = (data['interest'] as num).toDouble();

              final clientId = data['clientId'];

              String? dayDisplay;
              if (data.containsKey('day')) {
                final day = data['day'];
                if (day is String) {
                  dayDisplay = day;
                } else if (day is int) {
                  final daysOfWeek = [
                    'Lunes',
                    'Martes',
                    'Miércoles',
                    'Jueves',
                    'Viernes',
                    'Sábado',
                    'Domingo',
                  ];
                  if (day >= 1 && day <= 7) dayDisplay = daysOfWeek[day - 1];
                }
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('clients').doc(clientId).get(),
                builder: (context, clientSnapshot) {
                  if (clientSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(title: Text('Cargando cliente...'));
                  }
                  if (!clientSnapshot.hasData || !clientSnapshot.data!.exists) {
                    return const ListTile(title: Text('Cliente no encontrado'));
                  }

                  final clientData = clientSnapshot.data!.data() as Map<String, dynamic>;
                  final clientName = clientData['clientName'] ?? 'Sin nombre';

                  return Stack(
                    children: [
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreditInactiveDetailScreen(credit: credit),
                              ),
                            );
                          },
                          child: ListTile(
                            title: Text('Cliente: $clientName'),
                            subtitle: Text(
                              'Crédito: \$${NumberFormat('#,##0', 'es_CO').format(creditValue)}\n'
                              'Interés: ${interestPercent.toStringAsFixed(2)}%\n'
                              'Forma de pago: ${data['method']}\n'
                              '${dayDisplay != null ? 'Día: $dayDisplay\n' : ''}'
                              'Fecha: ${createdAt != null ? DateFormat('yyyy-MM-dd – kk:mm').format(createdAt) : 'N/A'}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
