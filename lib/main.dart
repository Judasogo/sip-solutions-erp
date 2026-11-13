  // Menú Flotante Rápido ERP Totalmente Operativo
  void _showQuickMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
          title: const Text('MENÚ RÁPIDO ERP', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
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

  // Diálogo interactivo para insertar registros reales en la base de datos
  void _showAddTransactionDialog(BuildContext context, String type) {
    final TextEditingController clientController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Text('Registrar $type', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientController,
                decoration: const InputDecoration(labelText: 'Nombre / Cliente / Producto', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto (€)', labelStyle: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final client = clientController.text;
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (client.isNotEmpty && amount > 0) {
                  String fechaHoy = DateTime.now().toString().substring(0, 10);
                  final nuevaTx = TransactionModel(
                    type: type,
                    client: client,
                    clientType: type == 'VENTA' ? 'Cliente Final' : 'General',
                    amount: amount,
                    paidAmount: amount,
                    paymentMode: 'Contado',
                    hasDelivery: 0,
                    status: 'Completada',
                    date: fechaHoy,
                  );
                  await ErpController.instance.insertTransaction(nuevaTx);
                  Navigator.pop(context);
                  _loadData(); // Recarga las tarjetas y la lista automáticamente
                }
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
