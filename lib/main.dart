import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _kardexFilter = 'TODOS';

  double _totalPorCobrar = 0.0;
  double _totalIngresos = 0.0;
  double _valorStock = 0.0;
  double _totalCompras = 0.0;
  int _lowStockCount = 0;

  List<TransactionModel> _pendingCobros = [];
  List<TransactionModel> _allTransactions = [];

  final TextEditingController _costController = TextEditingController(text: '37');
  final TextEditingController _marginController = TextEditingController(text: '143.24');

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  Future<void> _refreshAllData() async {
    final porCobrar = await ErpController.instance.getSum('COBRO');
    final ingresos = await ErpController.instance.getSum('VENTA');
    final stock = await ErpController.instance.getSum('PRODUCTO');
    final compras = await ErpController.instance.getSum('COMPRA');
    final lowStock = await ErpController.instance.getLowStockCount();
    final pendientes = await ErpController.instance.getPendingCobros();
    final todas = await ErpController.instance.getTransactions('TODOS');

    if (mounted) {
      setState(() {
        _totalPorCobrar = porCobrar;
        _totalIngresos = ingresos;
        _valorStock = stock;
        _totalCompras = compras;
        _lowStockCount = lowStock;
        _pendingCobros = pendientes;
        _allTransactions = todas;
      });
    }
  }

  Future<void> _exportData() async {
    final buffer = StringBuffer();
    buffer.writeln('ID;MODULO;CONCEPTO_PRODUCTO;PROVEEDOR_TARIFA;IMPORTE_PVP;PRECIO_COLAB_PAGO;METODO_COSTO;ESTADO;FECHA');
    for (var tx in _allTransactions) {
      buffer.writeln('${tx.id ?? ""};${tx.type};${tx.client};${tx.clientType};${tx.amount.toStringAsFixed(2)};${tx.paidAmount.toStringAsFixed(2)};${tx.paymentMode};${tx.status};${tx.date}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos exportados al portapapeles (formato CSV)'),
          backgroundColor: Color(0xFF3B82F6),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showQuickMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.blueAccent.withOpacity(0.35)),
          ),
          title: const Text(
            'MENÚ RÁPIDO ERP',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuickMenuItem(Icons.receipt_long_outlined, 'Nueva Cuenta por Cobrar', Colors.redAccent, () {
                Navigator.pop(context);
                _showAddTransactionDialog(context, 'COBRO');
              }),
              const SizedBox(height: 10),
              _buildQuickMenuItem(Icons.shopping_cart_outlined, 'Registrar Venta', const Color(0xFF10B981), () {
                Navigator.pop(context);
                _showAddTransactionDialog(context, 'VENTA');
              }),
              const SizedBox(height: 10),
              _buildQuickMenuItem(Icons.add_shopping_cart, 'Compra a Proveedor', Colors.orangeAccent, () {
                Navigator.pop(context);
                _showAddTransactionDialog(context, 'COMPRA');
              }),
              const SizedBox(height: 10),
              _buildQuickMenuItem(Icons.inventory_2_outlined, 'Nuevo Producto (PVP / Especial)', const Color(0xFF3B82F6), () {
                Navigator.pop(context);
                _showProductDialog(context);
              }),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0b0f19),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  // DIÁLOGO UNIFICADO DE PRODUCTO: PVP, ESPECIAL COLABORADOR, PROVEEDOR Y COSTO DE COMPRA
  void _showProductDialog(BuildContext context, {TransactionModel? existingProduct}) {
    final nameController = TextEditingController(text: existingProduct?.client ?? '');
    final pvpController = TextEditingController(
      text: existingProduct != null && existingProduct.amount > 0 ? existingProduct.amount.toStringAsFixed(2) : '',
    );
    final specialController = TextEditingController(
      text: existingProduct != null && existingProduct.paidAmount > 0 ? existingProduct.paidAmount.toStringAsFixed(2) : '',
    );

    final comprasProducto = existingProduct == null
        ? <TransactionModel>[]
        : _allTransactions
            .where((t) => t.type == 'COMPRA' && t.client.toLowerCase().contains(existingProduct.client.toLowerCase()))
            .toList();

    final providerController = TextEditingController(
      text: comprasProducto.isNotEmpty ? comprasProducto.first.clientType : '',
    );
    final costController = TextEditingController(
      text: existingProduct != null && existingProduct.paymentMode != 'Contado' && double.tryParse(existingProduct.paymentMode) != null && double.parse(existingProduct.paymentMode) > 0
          ? existingProduct.paymentMode
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
          ),
          title: Text(
            existingProduct == null ? 'Nuevo Producto en Stock' : 'Tarifas & Proveedores: ${existingProduct.client}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre del Producto (ej. Tíbet)',
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1f2937),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pvpController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'PVP Cliente Final (€) [Fijo]',
                    labelStyle: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF1f2937),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specialController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Precio Especial Colaborador (€) [Fijo]',
                    labelStyle: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF1f2937),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: providerController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Proveedor al que se compró (ej. Prov. Madrid)',
                    labelStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF1f2937),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Costo Compra de este Proveedor (€)',
                    labelStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1f2937),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                if (comprasProducto.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Proveedores registrados para este producto:', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...comprasProducto.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${c.clientType}: ${c.amount.toStringAsFixed(2)} € (${c.date})',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      )),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                final name = nameController.text.trim();
                final pvp = double.tryParse(pvpController.text.replaceAll(',', '.')) ?? 0.0;
                final special = double.tryParse(specialController.text.replaceAll(',', '.')) ?? pvp;
                final providerName = providerController.text.trim();
                final cost = double.tryParse(costController.text.replaceAll(',', '.')) ?? 0.0;

                if (name.isNotEmpty) {
                  String fechaHoy = DateTime.now().toString().substring(0, 10);

                  if (existingProduct != null && existingProduct.id != null) {
                    await ErpController.instance.updateProduct(existingProduct.id!, name, pvp, special, cost);
                  } else {
                    final prodTx = TransactionModel(
                      type: 'PRODUCTO',
                      client: name,
                      clientType: providerName.isNotEmpty ? providerName : 'General',
                      amount: pvp,
                      paidAmount: special,
                      paymentMode: cost.toStringAsFixed(2),
                      hasDelivery: false,
                      status: pvp > 0 ? 'Activo' : 'Stock Bajo',
                      date: fechaHoy,
                    );
                    await ErpController.instance.insertTransaction(prodTx);
                  }

                  // Si indicó proveedor o costo de compra, unifica automáticamente el registro en Compras/Kardex
                  if (providerName.isNotEmpty || cost > 0) {
                    final provFinal = providerName.isNotEmpty ? providerName : 'Proveedor General';
                    final yaExisteMismaCompra = comprasProducto.any(
                      (c) => c.clientType.toLowerCase() == provFinal.toLowerCase() && (c.amount - cost).abs() < 0.01,
                    );
                    if (!yaExisteMismaCompra) {
                      final compraTx = TransactionModel(
                        type: 'COMPRA',
                        client: '$name • Prov: $provFinal',
                        clientType: provFinal,
                        amount: cost,
                        paidAmount: cost,
                        paymentMode: 'Contado',
                        hasDelivery: false,
                        status: 'Completada',
                        date: fechaHoy,
                      );
                      await ErpController.instance.insertTransaction(compraTx);
                    }
                  }

                  if (context.mounted) Navigator.pop(context);
                  await _refreshAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Producto "$name" y proveedor sincronizados'),
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
  }

  // DIÁLOGO DE VENTA, COBRO Y COMPRA A MÚLTIPLES PROVEEDORES SIN ALTERAR EL PVP DE VENTA
  void _showAddTransactionDialog(BuildContext context, String type, {String? prefillClient, String? prefillClientType}) {
    final productos = _allTransactions.where((t) => t.type == 'PRODUCTO').toList();
    TransactionModel? selectedProduct = productos.isNotEmpty ? productos.first : null;

    final TextEditingController clientController = TextEditingController(text: prefillClient ?? '');
    final TextEditingController amountController = TextEditingController();

    String clientType = prefillClientType ?? (type == 'VENTA' || type == 'COBRO' ? 'Cliente Final' : 'Proveedor');
    String paymentMode = 'Contado';

    if ((type == 'VENTA' || type == 'COBRO') && selectedProduct != null) {
      double autoPrice = clientType == 'Colaborador' ? selectedProduct.paidAmount : selectedProduct.amount;
      if (autoPrice > 0) amountController.text = autoPrice.toStringAsFixed(2);
    }

    String titleLabel = 'Registrar Movimiento';
    String nameHint = 'Nombre / Concepto';
    if (type == 'VENTA') {
      titleLabel = 'Registrar Venta';
      nameHint = 'Nombre del Cliente o Colaborador';
    } else if (type == 'COMPRA') {
      titleLabel = 'Compra a Proveedor';
      nameHint = 'Nombre del Proveedor (ej. Prov. Madrid, Mayorista...)';
    } else if (type == 'COBRO') {
      titleLabel = 'Nueva Cuenta por Cobrar';
      nameHint = 'Cliente / Colaborador Deudor';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateAutoPrice(TransactionModel? prod, String cType) {
              if (prod == null || type == 'COMPRA') return;
              double price = cType == 'Colaborador' ? prod.paidAmount : prod.amount;
              if (price > 0) {
                amountController.text = price.toStringAsFixed(2);
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.blueAccent.withOpacity(0.35)),
              ),
              title: Text(titleLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (productos.isNotEmpty) ...[
                      DropdownButtonFormField<TransactionModel>(
                        value: selectedProduct,
                        dropdownColor: const Color(0xFF1f2937),
                        decoration: InputDecoration(
                          labelText: type == 'COMPRA' ? 'Producto Comprado' : 'Producto del Stock',
                          labelStyle: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1f2937),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        items: productos.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(
                              type == 'COMPRA'
                                  ? '${p.client} (PVP Venta: ${p.amount.toStringAsFixed(0)}€)'
                                  : '${p.client} (PVP ${p.amount.toStringAsFixed(0)}€ / Col ${p.paidAmount.toStringAsFixed(0)}€)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedProduct = val;
                            updateAutoPrice(val, clientType);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
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
                    if (type == 'VENTA' || type == 'COBRO') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: clientType,
                        dropdownColor: const Color(0xFF1f2937),
                        decoration: InputDecoration(
                          labelText: 'Tarifa Aplicada',
                          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1f2937),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Cliente Final', child: Text('Cliente Final (PVP)')),
                          DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador (Precio Especial)')),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            clientType = val!;
                            updateAutoPrice(selectedProduct, clientType);
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: type == 'COMPRA' ? 'Precio de Compra de este Proveedor (€)' : 'Importe Total (€)',
                        labelStyle: TextStyle(color: type == 'COMPRA' ? Colors.orangeAccent : Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1f2937),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                  onPressed: () async {
                    final rawName = clientController.text.trim();
                    final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                    if (rawName.isNotEmpty && amount >= 0) {
                      String fechaHoy = DateTime.now().toString().substring(0, 10);

                      if (type == 'COMPRA') {
                        String prodName = selectedProduct?.client ?? 'General';
                        final compraTx = TransactionModel(
                          type: 'COMPRA',
                          client: '$prodName • Prov: $rawName',
                          clientType: rawName,
                          amount: amount,
                          paidAmount: amount,
                          paymentMode: paymentMode,
                          hasDelivery: false,
                          status: 'Completada',
                          date: fechaHoy,
                        );
                        await ErpController.instance.insertTransaction(compraTx);

                        if (selectedProduct != null && selectedProduct!.id != null) {
                          await ErpController.instance.updateProduct(
                            selectedProduct!.id!,
                            selectedProduct!.client,
                            selectedProduct!.amount,
                            selectedProduct!.paidAmount,
                            amount,
                          );
                        }
                      } else {
                        String finalConcept = selectedProduct != null
                            ? '$rawName (${selectedProduct!.client})'
                            : rawName;

                        final nuevaTx = TransactionModel(
                          type: type,
                          client: finalConcept,
                          clientType: clientType,
                          amount: amount,
                          paidAmount: type == 'COBRO' ? 0.0 : amount,
                          paymentMode: paymentMode,
                          hasDelivery: false,
                          status: type == 'COBRO' ? 'Pendiente' : 'Completada',
                          date: fechaHoy,
                        );
                        await ErpController.instance.insertTransaction(nuevaTx);
                      }

                      if (context.mounted) Navigator.pop(context);
                      await _refreshAllData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$titleLabel registrado (PVP sin cambios)'),
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

  Widget _buildTopBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('J', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('ERP Juan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1f2937),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.45)),
                          ),
                          child: const Text('Por Juan', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 22),
                onPressed: () async {
                  await _refreshAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sincronizado con SQLite'), duration: Duration(seconds: 1)),
                    );
                  }
                },
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showQuickMenu(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: Row(
                    children: [
                      Icon(
                        _pendingCobros.isNotEmpty ? Icons.error_outline : Icons.check_circle_outline,
                        color: _pendingCobros.isNotEmpty ? Colors.redAccent : Colors.greenAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _pendingCobros.isNotEmpty
                              ? '${_pendingCobros.length} Deuda(s) Pendiente(s) • Cobrar ${_totalPorCobrar.toStringAsFixed(2)} €'
                              : '0 Deudas Pendientes • Todo al día',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: _exportData,
                child: Row(
                  children: const [
                    Icon(Icons.download_outlined, color: Colors.blueAccent, size: 15),
                    SizedBox(width: 4),
                    Text('Exportar', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInicioTab() {
    double costo = double.tryParse(_costController.text.replaceAll(',', '.')) ?? 0.0;
    double margen = double.tryParse(_marginController.text.replaceAll(',', '.')) ?? 0.0;
    double precioRecomendado = costo * (1 + margen / 100);
    double beneficioUnitario = precioRecomendado - costo;
    double beneficioNeto = _totalIngresos - _totalCompras;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBanner(),
          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.42,
            children: [
              _buildInteractiveCard(
                title: 'Por Cobrar',
                value: '${_totalPorCobrar.toStringAsFixed(2)} €',
                subtitle: '${_pendingCobros.length} Pendiente(s)',
                color: Colors.redAccent,
                icon: Icons.access_time,
                borderColor: Colors.redAccent.withOpacity(0.45),
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _buildInteractiveCard(
                title: 'Ingresos',
                value: '${_totalIngresos.toStringAsFixed(2)} €',
                subtitle: 'Neto: ${beneficioNeto.toStringAsFixed(2)} €',
                color: const Color(0xFF10B981),
                icon: Icons.euro,
                borderColor: Colors.white12,
                onTap: () {
                  setState(() {
                    _kardexFilter = 'VENTA';
                    _currentIndex = 3;
                  });
                },
              ),
              _buildInteractiveCard(
                title: 'Valor Stock',
                value: '${_valorStock.toStringAsFixed(2)} €',
                subtitle: 'Catálogo PVP activo',
                color: const Color(0xFF3B82F6),
                icon: Icons.inventory_2_outlined,
                borderColor: Colors.white12,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _buildInteractiveCard(
                title: 'Stock Bajo',
                value: '$_lowStockCount Prod.',
                subtitle: _lowStockCount > 0 ? 'Requieren precio/stock' : 'Catálogo completo',
                color: Colors.amber,
                icon: Icons.warning_amber_rounded,
                borderColor: Colors.white12,
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.notifications_none, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Text('Próximos Vencimientos de Cobro', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    InkWell(
                      onTap: () => setState(() => _currentIndex = 1),
                      child: const Text('Ver Todo', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_pendingCobros.isEmpty)
                  const Text('No hay cobros pendientes registrados.', style: TextStyle(color: Colors.grey, fontSize: 12))
                else
                  ..._pendingCobros.take(2).map((cobro) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0b0f19),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(cobro.client, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(cobro.status, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Text('${cobro.amount.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Rendimiento de Ventas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Ingresos vs Cuentas cobradas', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1f2937),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: const Text('EUR (€)', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SalesChartPainter(currentValue: _totalIngresos),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showAddTransactionDialog(context, 'COBRO'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long_outlined, color: Colors.redAccent, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Nueva Cta. Cobrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Registrar crédito', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showAddTransactionDialog(context, 'VENTA'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Nueva Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('PVP / Colaborador', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
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
                const Text('Simula margen según el costo de cada proveedor.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Costo Proveedor (€)',
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
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildCobrosTab() {
    final cobros = _allTransactions.where((t) => t.type == 'COBRO').toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cuentas por Cobrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Nuevo Cobro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddTransactionDialog(context, 'COBRO'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cobros.isEmpty
                ? const Center(child: Text('No hay cuentas por cobrar registradas.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: cobros.length,
                    itemBuilder: (context, index) {
                      final item = cobros[index];
                      final isPaid = item.status == 'Cobrado';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isPaid ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.client, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text('${item.clientType} • ${item.paymentMode} • ${item.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  const SizedBox(height: 6),
                                  Text('${item.amount.toStringAsFixed(2)} €', style: TextStyle(color: isPaid ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                            if (!isPaid && item.id != null)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                onPressed: () async {
                                  await ErpController.instance.markCobroAsPaid(item.id!, item.amount);
                                  await _refreshAllData();
                                },
                                child: const Text('Cobrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              )
                            else
                              const Chip(label: Text('Cobrado', style: TextStyle(color: Colors.greenAccent, fontSize: 11))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // MÓDULO STOCK CON PVP FIJO, PRECIO ESPECIAL Y PROVEEDORES MÚLTIPLES POR PRODUCTO
  Widget _buildStockTab() {
    final productos = _allTransactions.where((t) => t.type == 'PRODUCTO').toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Inventario & Tarifas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Nuevo Producto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showProductDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('PVP y Especial son fijos; los costos varían según proveedor.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 12),
          Expanded(
            child: productos.isEmpty
                ? const Center(child: Text('No hay productos registrados.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final prod = productos[index];
                      final isLow = prod.amount <= 0;
                      final comprasDeEsteProd = _allTransactions
                          .where((t) => t.type == 'COMPRA' && t.client.toLowerCase().contains(prod.client.toLowerCase()))
                          .toList();

                      final listaProveedores = comprasDeEsteProd.isNotEmpty
                          ? comprasDeEsteProd.map((c) => "${c.clientType} (${c.amount.toStringAsFixed(2)}€)").toSet().join(" • ")
                          : (prod.clientType != 'General' ? '${prod.clientType} (${prod.paymentMode}€)' : '');

                      return InkWell(
                        onTap: () => _showProductDialog(context, existingProduct: prod),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isLow ? Colors.amber.withOpacity(0.45) : Colors.blueAccent.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, color: isLow ? Colors.amber : Colors.blueAccent, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(prod.client, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    if (isLow)
                                      const Text('Sin tarifa asignada • Toca para configurar PVP', style: TextStyle(color: Colors.amber, fontSize: 11))
                                    else ...[
                                      Row(
                                        children: [
                                          Text('PVP: ${prod.amount.toStringAsFixed(2)} €', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                                          const SizedBox(width: 10),
                                          Text('Especial Col.: ${prod.paidAmount.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      if (listaProveedores.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Proveedor: $listaProveedores',
                                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                onPressed: () => _showProductDialog(context, existingProduct: prod),
                              ),
                              if (prod.id != null)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                  onPressed: () async {
                                    await ErpController.instance.deleteTransaction(prod.id!);
                                    await _refreshAllData();
                                  },
                                ),
                            ],
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

  Widget _buildKardexTab() {
    final filtered = _kardexFilter == 'TODOS'
        ? _allTransactions
        : _allTransactions.where((t) => t.type == _kardexFilter).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kardex de Movimientos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['TODOS', 'VENTA', 'COMPRA', 'COBRO', 'PRODUCTO'].map((f) {
                final sel = _kardexFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.grey)),
                    selected: sel,
                    selectedColor: const Color(0xFF3B82F6),
                    backgroundColor: const Color(0xFF111827),
                    onSelected: (_) => setState(() => _kardexFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Sin movimientos en este filtro.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tx = filtered[index];
                      Color badgeColor = Colors.blueAccent;
                      if (tx.type == 'VENTA') badgeColor = const Color(0xFF10B981);
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
                          title: Text(tx.client, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                          subtitle: Text(
                            tx.type == 'PRODUCTO'
                                ? 'PRODUCTO • PVP: ${tx.amount.toStringAsFixed(2)} € | Col: ${tx.paidAmount.toStringAsFixed(2)} €'
                                : tx.type == 'COMPRA'
                                    ? 'COMPRA • Proveedor: ${tx.clientType} (${tx.paymentMode}) • ${tx.date}'
                                    : '${tx.type} • ${tx.clientType} (${tx.paymentMode}) • ${tx.date}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${tx.amount.toStringAsFixed(2)} €', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: badgeColor)),
                              if (tx.id != null)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                  onPressed: () async {
                                    await ErpController.instance.deleteTransaction(tx.id!);
                                    await _refreshAllData();
                                  },
                                ),
                            ],
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

  Widget _buildClientesTab() {
    final operacionesClientes = _allTransactions.where((t) => t.type == 'VENTA' || t.type == 'COBRO').toList();

    final Map<String, Map<String, dynamic>> clientesMap = {};
    for (var op in operacionesClientes) {
      String cleanName = op.client.contains('(') ? op.client.split('(').first.trim() : op.client.trim();
      if (cleanName.isEmpty) cleanName = op.client;

      if (!clientesMap.containsKey(cleanName)) {
        clientesMap[cleanName] = {
          'name': cleanName,
          'type': op.clientType,
          'totalVentas': 0.0,
          'pendiente': 0.0,
          'count': 0,
        };
      }
      clientesMap[cleanName]!['count'] = (clientesMap[cleanName]!['count'] as int) + 1;
      if (op.type == 'VENTA' || op.status == 'Cobrado') {
        clientesMap[cleanName]!['totalVentas'] = (clientesMap[cleanName]!['totalVentas'] as double) + op.amount;
      } else if (op.type == 'COBRO' && op.status != 'Cobrado') {
        clientesMap[cleanName]!['pendiente'] = (clientesMap[cleanName]!['pendiente'] as double) + op.amount;
      }
      if (op.clientType == 'Colaborador') {
        clientesMap[cleanName]!['type'] = 'Colaborador';
      }
    }

    final listaClientes = clientesMap.values.toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Clientes & Colaboradores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
                label: const Text('Nueva Venta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddTransactionDialog(context, 'VENTA'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Toca un cliente o colaborador para registrarle una venta con su tarifa.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 12),
          Expanded(
            child: listaClientes.isEmpty
                ? const Center(child: Text('Registra una venta o cobro para alimentar este directorio.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: listaClientes.length,
                    itemBuilder: (context, index) {
                      final cli = listaClientes[index];
                      final isColab = cli['type'] == 'Colaborador';
                      final double pendiente = cli['pendiente'] as double;
                      final double totalVentas = cli['totalVentas'] as double;

                      return InkWell(
                        onTap: () => _showAddTransactionDialog(
                          context,
                          'VENTA',
                          prefillClient: cli['name'],
                          prefillClientType: cli['type'],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isColab ? Colors.purpleAccent.withOpacity(0.4) : Colors.blueAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isColab ? Colors.purpleAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                                child: Icon(Icons.person, color: isColab ? Colors.purpleAccent : Colors.blueAccent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cli['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Tarifa: ${isColab ? "Colaborador (Especial)" : "Cliente Final (PVP)"} • ${cli['count']} op.',
                                      style: TextStyle(color: isColab ? Colors.purpleAccent : Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${totalVentas.toStringAsFixed(2)} €', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15)),
                                  if (pendiente > 0)
                                    Text('Debe: ${pendiente.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
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

  Widget _buildInteractiveCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: title == 'Por Cobrar' ? color : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildInicioTab(),
      _buildCobrosTab(),
      _buildStockTab(),
      _buildKardexTab(),
      _buildClientesTab(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () => _showQuickMenu(context),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111827),
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Cobros'),
          BottomNavigationBarItem(icon: Icon(Icons.hub_outlined), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Kardex'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Clientes'),
        ],
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  final double currentValue;
  _SalesChartPainter({required this.currentValue});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      double y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    double factor = currentValue > 0 ? 1.0 : 0.4;
    final points = [
      Offset(12, size.height * 0.85),
      Offset(size.width * 0.35, size.height * (0.55 * factor)),
      Offset(size.width * 0.68, size.height * (0.42 * factor)),
      Offset(size.width - 12, size.height * (0.18 * factor)),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (var p in points) {
      canvas.drawCircle(p, 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) => oldDelegate.currentValue != currentValue;
}
