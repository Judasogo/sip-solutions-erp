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
      title: 'ERP Juan',
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
  double _totalCobros = 0.0;
  String _selectedFilter = 'TODOS';

  final TextEditingController _costController = TextEditingController(text: '37');
  final TextEditingController _marginController = TextEditingController(text: '143.24');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _transactionsFuture = ErpController.instance.getTransactions(_selectedFilter);
    });
    ErpController.instance.getSum('VENTA').then((val) => setState(() => _totalVentas = val));
    ErpController.instance.getSum('COMPRA').then((val) => setState(() => _totalCompras = val));
    ErpController.instance.getSum('COBRO').then((val) => setState(() => _totalCobros = val));
  }

  void _showQuickMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
          ),
          title: const Text(
            'MENÚ RÁPIDO ERP',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuickMenuItem(Icons.receipt_long_outlined, 'Nueva Cuenta por Cobrar', Colors.redAccent, () {
                Navigator.pop(context);
                _showAddTransactionDialog(context, 'COBRO');
              }),
              const SizedBox(height: 8),
              _buildQuickMenuItem(Icons.shopping_cart_outlined, 'Registrar Venta', Colors.greenAccent, () {
                Navigator.pop(context);
                _showAddTransactionDialog(context, 'VENTA');
              }),
              const SizedBox(height: 8),
              _buildQuickMenuItem(Icons.inventory_2_outlined, 'Nuevo Producto', Colors.blueAccent, () {
                Navigator.pop(context);
                _showAddTransactionDialog(context, 'PRODUCTO');
              }),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickMenuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1f2937),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, String type) {
    final TextEditingController clientController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String clientType = type == 'VENTA' ? 'Cliente Final' : 'General';
    String paymentMode = 'Contado';

    String titleLabel = 'Registrar Movimiento';
    String nameHint = 'Nombre / Concepto';
    if (type == 'VENTA') {
      titleLabel = 'Registrar Nueva Venta';
      nameHint = 'Producto o Cliente (ej. Mónaco)';
    } else if (type == 'COMPRA') {
      titleLabel = 'Registrar Nueva Compra';
      nameHint = 'Proveedor o Producto';
    } else if (type == 'COBRO') {
      titleLabel = 'Nueva Cuenta por Cobrar';
      nameHint = 'Nombre del Deudor / Cliente';
    } else if (type == 'PRODUCTO') {
      titleLabel = 'Alta de Nuevo Producto';
      nameHint = 'Nombre del Producto (ej. Tíbet)';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              title: Text(titleLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: clientController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: nameHint,
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1f2937),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: type == 'PRODUCTO' ? 'Costo Base (€)' : 'Importe (€)',
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1f2937),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    if (type == 'VENTA' || type == 'COBRO') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: clientType,
                        dropdownColor: const Color(0xFF1f2937),
                        decoration: InputDecoration(
                          labelText: 'Tarifa / Tipo',
                          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1f2937),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Cliente Final', child: Text('Cliente Final')),
                          DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador')),
                        ],
                        onChanged: (val) => setDialogState(() => clientType = val!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: paymentMode,
                        dropdownColor: const Color(0xFF1f2937),
                        decoration: InputDecoration(
                          labelText: 'Método de Pago',
                          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1f2937),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Contado', child: Text('Contado / Efectivo')),
                          DropdownMenuItem(value: 'Bizum', child: Text('Bizum')),
                        ],
                        onChanged: (val) => setDialogState(() => paymentMode = val!),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    final client = clientController.text.trim();
                    final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                    if (client.isNotEmpty && amount >= 0) {
                      String fechaHoy = DateTime.now().toString().substring(0, 10);
                      final nuevaTx = TransactionModel(
                        type: type,
                        client: client,
                        clientType: clientType,
                        amount: amount,
                        paidAmount: type == 'COBRO' ? 0.0 : amount,
                        paymentMode: paymentMode,
                        hasDelivery: 0,
                        status: type == 'COBRO' ? 'Pendiente' : 'Completada',
                        date: fechaHoy,
                      );
                      await ErpController.instance.insertTransaction(nuevaTx);
                      if (context.mounted) Navigator.pop(context);
                      _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$type registrado correctamente'),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double rentabilidad = _totalVentas - _totalCompras;
    double costo = double.tryParse(_costController.text.replaceAll(',', '.')) ?? 0.0;
    double margen = double.tryParse(_marginController.text.replaceAll(',', '.')) ?? 0.0;
    double precioRecomendado = costo * (1 + margen / 100);
    double beneficioUnitario = precioRecomendado - costo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: _loadData,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
                    child: const Text('J', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ERP Juan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        const SizedBox(height: 2),
                        Row(
                          children: const [
                            Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                            SizedBox(width: 6),
                            Text('Cuentas & Alertas Activas', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1f2937),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.4)),
                    ),
                    child: const Text('Por Juan', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                    onPressed: () => _showAddTransactionDialog(context, 'VENTA'),
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
                    onPressed: () => _showAddTransactionDialog(context, 'COMPRA'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard('VENTAS TOTALES', '${_totalVentas.toStringAsFixed(2)} €', 'Ingresos registrados', Colors.blueAccent, Icons.trending_up),
                _buildMetricCard('BENEFICIO NETO', '${rentabilidad.toStringAsFixed(2)} €', 'Ventas - Compras', Colors.greenAccent, Icons.account_balance_wallet_outlined),
                _buildMetricCard('POR COBRAR', '${_totalCobros.toStringAsFixed(2)} €', 'Cuentas pendientes', Colors.redAccent, Icons.pending_actions),
                _buildMetricCard('COMPRAS / COSTO', '${_totalCompras.toStringAsFixed(2)} €', 'Inversión stock', Colors.orangeAccent, Icons.inventory_outlined),
              ],
            ),
            const SizedBox(height: 20),
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
                  const Text('Simula precios para Cliente Final o Colaborador.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _costController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            const Text('Módulos & Movimientos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['TODOS', 'VENTA', 'COMPRA', 'COBRO', 'PRODUCTO'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
                      selected: isSelected,
                      selectedColor: Colors.blueAccent,
                      backgroundColor: const Color(0xFF111827),
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                        _loadData();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 340,
              child: FutureBuilder<List<TransactionModel>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No hay registros en este módulo.', style: TextStyle(color: Colors.grey)));
                  }

                  final transactions = snapshot.data!;
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      Color badgeColor = Colors.blueAccent;
                      if (tx.type == 'VENTA') badgeColor = Colors.greenAccent;
                      if (tx.type == 'COMPRA') badgeColor = Colors.orangeAccent;
                      if (tx.type == 'COBRO') badgeColor = Colors.redAccent;

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
                          subtitle: Text(
                            '${tx.type} • ${tx.clientType} (${tx.paymentMode}) • ${tx.date}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${tx.amount.toStringAsFixed(2)} €',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: badgeColor),
                              ),
                              if (tx.id != null)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                  onPressed: () async {
                                    await ErpController.instance.deleteTransaction(tx.id!);
                                    _loadData();
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => _showQuickMenu(context),
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
