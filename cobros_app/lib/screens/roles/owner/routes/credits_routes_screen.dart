import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/pays_details.dart';
import 'Liquidation_Screen.dart';

class CreditsRoutesScreen extends StatelessWidget {
  const CreditsRoutesScreen({
    super.key,
    required this.collectorId,
    required this.collectorName,
    required this.userId,
    required this.officeId,
  });

  final String collectorId;
  final String collectorName;
  final String userId;
  final String officeId;

  Stream<List<Map<String, dynamic>>> getActiveCreditsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('offices')
        .doc(officeId)
        .collection('clients')
        .where('createdBy', isEqualTo: collectorId)
        .snapshots()
        .asyncMap((clientsSnapshot) async {
          final creditsWithClient = <Map<String, dynamic>>[];

          for (final clientDoc in clientsSnapshot.docs) {
            final creditsSnapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('offices')
                    .doc(officeId)
                    .collection('clients')
                    .doc(clientDoc.id)
                    .collection('credits')
                    .where('isActive', isEqualTo: true)
                    .get();

            for (final creditDoc in creditsSnapshot.docs) {
              final paymentsSnapshot = await creditDoc.reference.collection('payments').get();

              creditsWithClient.add({
                'creditData': creditDoc.data(),
                'creditId': creditDoc.id,
                'clientData': clientDoc.data(),
                'clientId': clientDoc.id,
                'payments': paymentsSnapshot.docs.map((doc) => doc.data()).toList(),
              });
            }
          }

          return creditsWithClient;
        });
  }

  int countPayments(List<Map<String, dynamic>> payments) {
    return payments.length;
  }

  double sumPayments(List<Map<String, dynamic>> payments) {
    return payments.fold(0.0, (sum, payment) => sum + (payment['amount'] ?? 0).toDouble());
  }

  Color _getMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'diario':
        return Colors.blue;
      case 'semanal':
        return Colors.green;
      case 'quincenal':
        return Colors.orange;
      case 'mensual':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'diario':
        return Icons.calendar_view_day;
      case 'semanal':
        return Icons.calendar_view_week;
      case 'quincenal':
        return Icons.event_available;
      case 'mensual':
        return Icons.calendar_today;
      default:
        return Icons.payment;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Créditos de $collectorName')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getActiveCreditsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          return _buildCreditsList(snapshot.data!);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToLiquidation(context),
        icon: const Icon(Icons.monetization_on),
        label: const Text('Liquidar'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No hay créditos activos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Este cobrador no tiene créditos activos actualmente',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsList(List<Map<String, dynamic>> credits) {
    return ListView.builder(
      itemCount: credits.length,
      itemBuilder: (context, index) {
        final creditInfo = credits[index];
        final creditData = creditInfo['creditData'];
        final clientData = creditInfo['clientData'];
        final payments = creditInfo['payments'] as List<Map<String, dynamic>>;

        final clientName = clientData['clientName'] ?? 'Cliente desconocido';
        final credit = (creditData['credit'] ?? 0).toDouble();
        final interest = (creditData['interest'] ?? 0).toDouble();
        final method = creditData['method'] ?? 'Sin método';
        final cout = (creditData['cuot'] ?? 0).toInt();
        final totalCredit = ((credit * interest) / 100) + credit;
        final paymentValue = totalCredit / cout;
        final paymentsCount = countPayments(payments);
        final totalPaid = sumPayments(payments);
        final restPay = (totalCredit - totalPaid);

        final methodColor = _getMethodColor(method);
        final methodIcon = _getMethodIcon(method);

        return _buildCreditCard(
          context,
          clientName: clientName,
          method: method,
          methodColor: methodColor,
          methodIcon: methodIcon,
          paymentsCount: paymentsCount,
          cout: cout,
          totalCredit: totalCredit,
          totalPaid: totalPaid,
          restPay: restPay,
          paymentValue: paymentValue,
          onTap: () => _navigateToPayDetails(context, creditInfo),
        );
      },
    );
  }

  Widget _buildCreditCard(
    BuildContext context, {
    required String clientName,
    required String method,
    required Color methodColor,
    required IconData methodIcon,
    required int paymentsCount,
    required int cout,
    required double totalCredit,
    required double totalPaid,
    required double restPay,
    required double paymentValue,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${paymentsCount}/$cout',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor:
                        paymentsCount == cout ? Colors.green : Theme.of(context).primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(methodIcon, size: 18, color: methodColor),
                  const SizedBox(width: 8),
                  Text(method, style: TextStyle(fontWeight: FontWeight.bold, color: methodColor)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: paymentsCount / cout,
                backgroundColor: Colors.grey[200],
                color: paymentsCount == cout ? Colors.green : Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Total', '\$${totalCredit.toStringAsFixed(2)}'),
                      _buildInfoRow('Abonado', '\$${totalPaid.toStringAsFixed(2)}'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildInfoRow('Faltante', '\$${restPay.toStringAsFixed(2)}'),
                      _buildInfoRow('Cuota', '\$${paymentValue.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPayDetails(BuildContext context, Map<String, dynamic> creditInfo) {
    final clientId = creditInfo['clientId'] as String;
    final creditId = creditInfo['creditId'] as String;
    Navigator.push(context, MaterialPageRoute(builder: (context) => PaysDetails(credit: creditId)));
  }

  void _navigateToLiquidation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CollectorLiquidationScreen(
              officeId: officeId,
              collectorId: collectorId,
              collectorName: collectorName,
            ),
      ),
    );
  }
}
