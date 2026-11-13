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
                
