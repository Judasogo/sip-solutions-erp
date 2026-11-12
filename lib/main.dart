import 'package:flutter/material.dart';
import 'controllers/erp_controller.dart';
import 'models/transaction_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ErpApp());
}

class ErpApp extends StatelessWidget {
  const ErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIP Solutions ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0b0f19),
        cardColor: const Color(0xFF111827),
        primaryColor: Colors.blueAccent,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;
  double _totalVentas = 0.0;
  double _totalCompras = 0.0;

  // Controladores para la calculadora interactiva en vivo
  final TextEditingController _costController = TextEditingController(text: '150');
  final TextEditingController _marginController = TextEditingController(text: '40');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _transactionsFuture = ErpController.instance.getTransactions();
    ErpController.instance.getSum('VENTA').then((val) => setState(() => _totalVentas = val));
    ErpController.instance.getSum('COMPRA').then((val) => setState(() => _totalCompras = val));
  }

  @override
  Widget build(BuildContext context) {
    double rentabilidad = _totalVentas - _totalCompras;
    double costo = double.tryParse(_costController.text) ?? 0.0;
    double margen = double.tryParse(_marginController.text) ?? 0.0;
    double precioRecomendado = costo * (1 + margen / 100);
    double beneficioUnitario = precioRecomendado - costo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.grey),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BOTONES DE ACCIÓN PRINCIPAL
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('+ Nueva Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                    label: const Text('+ Nueva Compra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ALERTA DE STOCK CRÍTICO
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1f1619),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock Crítico Mínimo (3 Productos)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Notificación de stock por debajo del nivel de reabastecimiento.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // TARJETAS DE MÉTRICAS FINANCIERAS (GRID)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard('VENTAS TOTALES', '${_totalVentas.toStringAsFixed(2)} €', '+42.7%', Colors.blueAccent, Icons.trending_up),
                _buildMetricCard('BENEFICIO NETO', '${rentabilidad.toStringAsFixed(2)} €', 'Ganancia Bruta', Colors.greenAccent, Icons.account_balance_wallet_outlined),
                _buildMetricCard('MARGEN PROMEDIO', '38.7%', 'Margen / Ventas', Colors.purpleAccent, Icons.pie_chart_outline),
                _buildMetricCard('TRANSACCIONES', '1,852', '+19.3%', Colors.orangeAccent, Icons.receipt_long),
              ],
            ),
            const SizedBox(height: 20),

            // CALCULADORA & SIMULADOR DE PRECIOS EN VIVO
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calculate_outlined, color: Colors.blueAccent, size: 20),
                      SizedBox(width: 8),
                      Text('Calculadora & Simulador en Vivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Calcula precios de venta y beneficio bruto por producto.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Costo Unitario (€)',
                            labelStyle: TextStyle(fontSize: 12, color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF1f2937),
                            border: OutlineInputBorder(borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _marginController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Margen Deseado (%)',
                            labelStyle: TextStyle(fontSize: 12, color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF1f2937),
                            border: OutlineInputBorder(borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1f2937),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PRECIO VENTA RECOMENDADO', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${precioRecomendado.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('BENEFICIO UNITARIO', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${beneficioUnitario.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN DE TRANSACCIONES & KARDEX
            const Text('Clientes, Ventas y Margen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),

            SizedBox(
              height: 320,
              child: FutureBuilder<List<TransactionModel>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No hay transacciones registradas.'));
                  }

                  final transactions = snapshot.data!;
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          title: Text(tx.client, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                          subtitle: Text('Tipo: ${tx.type} | Fecha: ${tx.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: Text(
                            '${tx.amount.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: tx.type == 'VENTA' ? Colors.greenAccent : (tx.type == 'COMPRA' ? Colors.orangeAccent : Colors.blueAccent),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
