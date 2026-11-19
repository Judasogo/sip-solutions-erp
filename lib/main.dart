import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ERPJuanApp());
}

class ERPJuanApp extends StatelessWidget {
  const ERPJuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ERP Juan',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1A),
        primaryColor: const Color(0xFF2F81F7),
        cardColor: const Color(0xFF121927),
        dialogBackgroundColor: const Color(0xFF121927),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2F81F7),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF121927),
          error: Color(0xFFEF4444),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B2436),
          labelStyle: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.w500),
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A364E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2F81F7), width: 1.6),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A364E)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const DashboardPrincipal(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('erp_juan_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        costo_compra REAL NOT NULL DEFAULT 0.0,
        precio_pvp REAL NOT NULL DEFAULT 0.0,
        precio_colaborador REAL NOT NULL DEFAULT 0.0,
        proveedor TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        tipo TEXT NOT NULL DEFAULT 'Cliente Final',
        telefono TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        producto_id INTEGER,
        producto_nombre TEXT NOT NULL,
        cliente_proveedor TEXT NOT NULL,
        tarifa TEXT DEFAULT 'PVP',
        cantidad INTEGER NOT NULL DEFAULT 1,
        precio_unitario REAL NOT NULL DEFAULT 0.0,
        importe REAL NOT NULL DEFAULT 0.0,
        metodo_pago TEXT DEFAULT 'Contado / Efectivo',
        estado_cobro TEXT DEFAULT 'Pagado',
        fecha TEXT NOT NULL,
        fecha_vencimiento TEXT NOT NULL
      )
    ''');
  }

  Future<void> asegurarCliente(String nombre, String tipoTarifa) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty || limpio == 'Cliente General') return;
    final db = await database;
    final existe = await db.query(
      'clientes',
      where: 'LOWER(nombre) = ?',
      whereArgs: [limpio.toLowerCase()],
    );
    if (existe.isEmpty) {
      await db.insert('clientes', {
        'nombre': limpio,
        'tipo': tipoTarifa.contains('Colab') ? 'Colaborador' : 'Cliente Final',
        'telefono': '',
      });
    }
  }
}

Widget _botonGuardarBusiness({required String texto, required VoidCallback onPressed}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF2F81F7),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
    ),
    onPressed: onPressed,
    child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  );
}

class DashboardPrincipal extends StatefulWidget {
  const DashboardPrincipal({super.key});

  @override
  State<DashboardPrincipal> createState() => _DashboardPrincipalState();
}

class _DashboardPrincipalState extends State<DashboardPrincipal> {
  double porCobrarTotal = 0.0;
  double vencidasTotal = 0.0;
  int vencidasCount = 0;
  double ingresosTotales = 0.0;
  double ingresosMesActual = 0.0;
  double valorStock = 0.0;
  int stockBajoCount = 0;

  List vencimientosProximos = [];
  List movimientosTodos = [];
  List puntosGrafica = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List etiquetasMeses = ['Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov'];

  String filtroKardex = 'TODOS';

  @override
  void initState() {
    super.initState();
    _refrescarTodo();
  }

  Future<void> _refrescarTodo() async {
    final db = await DatabaseHelper.instance.database;
    final movs = await db.query('movimientos', orderBy: 'id DESC');
    final prods = await db.query('productos', orderBy: 'nombre ASC');

    double pCobrar = 0.0;
    double vTotal = 0.0;
    int vCount = 0;
    double ingTotal = 0.0;
    double ingMes = 0.0;

    final ahora = DateTime.now();
    final hoySoloFecha = DateTime(ahora.year, ahora.month, ahora.day);
    final prefijoMesActual = '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';

    List listaVencimientos = [];

    List mesesKeys = [];
    List mesesLabels = [];
    const nombresMes = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(ahora.year, ahora.month - i, 1);
      mesesKeys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
      mesesLabels.add(nombresMes[d.month - 1]);
    }
    List sumasMes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

    for (var m in movs) {
      final tipo = (m['tipo'] ?? '').toString().toUpperCase();
      final imp = (m['importe'] as num?)?.toDouble() ?? 0.0;
      final estado = (m['estado_cobro'] ?? 'Pagado').toString();
      final fechaStr = (m['fecha'] ?? '').toString();
      final vencStr = (m['fecha_vencimiento'] ?? fechaStr).toString();

      if (tipo == 'VENTA' || tipo == 'COBRO') {
        if (estado == 'Pendiente') {
          pCobrar += imp;
          final fVenc = DateTime.tryParse(vencStr) ?? hoySoloFecha;
          final diffDias = hoySoloFecha.difference(DateTime(fVenc.year, fVenc.month, fVenc.day)).inDays;
          if (diffDias > 0) {
            vCount++;
            vTotal += imp;
          }
          final itemCopia = Map.from(m);
          itemCopia['dias_retraso'] = diffDias;
          listaVencimientos.add(itemCopia);
        } else {
          ingTotal += imp;
          if (fechaStr.startsWith(prefijoMesActual)) {
            ingMes += imp;
          }
          for (int idx = 0; idx < 6; idx++) {
            if (fechaStr.startsWith(mesesKeys[idx])) {
              sumasMes[idx] = (sumasMes[idx] as double) + imp;
            }
          }
        }
      }
    }

    listaVencimientos.sort((a, b) => (b['dias_retraso'] as int).compareTo(a['dias_retraso'] as int));

    double vStock = 0.0;
    int sBajo = 0;
    for (var pr in prods) {
      final st = (pr['stock'] as int?) ?? 0;
      final costo = (pr['costo_compra'] as num?)?.toDouble() ?? 0.0;
      vStock += st * costo;
      if (st <= 3) sBajo++;
    }

    if (mounted) {
      setState(() {
        porCobrarTotal = pCobrar;
        vencidasTotal = vTotal;
        vencidasCount = vCount;
        ingresosTotales = ingTotal;
        ingresosMesActual = ingMes;
        valorStock = vStock;
        stockBajoCount = sBajo;
        vencimientosProximos = listaVencimientos;
        movimientosTodos = movs;
        puntosGrafica = sumasMes;
        etiquetasMeses = mesesLabels;
      });
    }
  }

  Future<void> _exportarResumen() async {
    final buffer = StringBuffer();
    buffer.writeln('=== REPORTE ERP JUAN ===');
    buffer.writeln('Ingresos Totales: ${ingresosTotales.toStringAsFixed(2)} €');
    buffer.writeln('Por Cobrar: ${porCobrarTotal.toStringAsFixed(2)} € ($vencidasCount vencidas)');
    buffer.writeln('Valor Inventario: ${valorStock.toStringAsFixed(2)} €');
    buffer.writeln('Productos Stock Bajo: $stockBajoCount');
    buffer.writeln('\n--- ÚLTIMOS MOVIMIENTOS ---');
    for (var m in movimientosTodos.take(15)) {
      buffer.writeln('${m['fecha']} | ${m['tipo']} | ${m['cliente_proveedor']} | ${m['producto_nombre']} x${m['cantidad'] ?? 1} | ${m['importe']} € (${m['estado_cobro']})');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Reporte copiado al portapapeles listo para pegar en WhatsApp o Notas.'),
        ),
      );
    }
  }

  void _abrirMenuRapido() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121927),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Acciones & Módulos ERP Juan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
                    label: const Text('Nueva Venta', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      mostrarDialogoVenta(context, _refrescarTodo);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F81F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.inventory_rounded, size: 19),
                    label: const Text('Nueva Compra', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      mostrarDialogoCompra(context, _refrescarTodo);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF60A5FA)),
              title: const Text('Inventario & Tarifas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Productos, precios PVP / Especial Colaborador y stock', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StockScreen(onChanged: _refrescarTodo)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined, color: Color(0xFF10B981)),
              title: const Text('Clientes & Colaboradores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Base de datos autorrellenable y tarifas', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ClientesScreen(onChanged: _refrescarTodo)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined, color: Colors.amberAccent),
              title: const Text('Calculadora de Márgenes PVP / Colab', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Simula precios y beneficios unitarios', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarCalculadoraDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarCalculadoraDialog() {
    final costoCtrl = TextEditingController(text: '37');
    final margenCtrl = TextEditingController(text: '50');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) {
          final costo = double.tryParse(costoCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final margen = double.tryParse(margenCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final pvp = costo * (1 + margen / 100);
          final ben = pvp - costo;
          return AlertDialog(
            backgroundColor: const Color(0xFF121927),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF23304A))),
            title: const Text('Simulador de Precios', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: costoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Costo Unitario (€)'),
                  onChanged: (_) => setStateDlg(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: margenCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Margen Deseado (%)'),
                  onChanged: (_) => setStateDlg(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2436),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A364E)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PVP: ${pvp.toStringAsFixed(2)} €', style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('+${ben.toStringAsFixed(2)} €', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar', style: TextStyle(color: Colors.grey))),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List movsFiltrados = [];
    if (filtroKardex == 'TODOS') {
      movsFiltrados = movimientosTodos;
    } else if (filtroKardex == 'VENTA') {
      movsFiltrados = movimientosTodos.where((m) {
        final t = (m['tipo'] ?? '').toString().toUpperCase();
        return t == 'VENTA' || t == 'COBRO';
      }).toList();
    } else {
      movsFiltrados = movimientosTodos.where((m) => (m['tipo'] ?? '').toString().toUpperCase() == filtroKardex).toList();
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refrescarTodo,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F81F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('J', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('ERP Juan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B263B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF2F81F7).withOpacity(0.5)),
                              ),
                              child: const Text('DARK UI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('Cuentas & Alertas Activas', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    onPressed: _refrescarTodo,
                  ),
                  GestureDetector(
                    onTap: _abrirMenuRapido,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F81F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A151D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$vencidasCount Deuda(s) Vencida(s) · Cobrar ${porCobrarTotal.toStringAsFixed(0)} €',
                        style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ),
                    GestureDetector(
                      onTap: _exportarResumen,
                      child: const Row(
                        children: [
                          Icon(Icons.download_rounded, color: Color(0xFF60A5FA), size: 16),
                          SizedBox(width: 4),
                          Text('Exportar', style: TextStyle(fontSize: 12, color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _kpiTarjeta(
                      titulo: 'Por Cobrar',
                      valor: '${porCobrarTotal.toStringAsFixed(2)} €',
                      subtitulo: '$vencidasCount Vencidas (${vencidasTotal.toStringAsFixed(0)} €)',
                      subColor: const Color(0xFFEF4444),
                      icono: Icons.access_time_rounded,
                      iconColor: const Color(0xFFEF4444),
                      bordeColor: const Color(0xFFEF4444).withOpacity(0.45),
                      showWarningIcon: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _kpiTarjeta(
                      titulo: 'Ingresos',
                      valor: '${ingresosTotales.toStringAsFixed(2)} €',
                      subtitulo: '+${ingresosMesActual.toStringAsFixed(2)} € este mes',
                      subColor: const Color(0xFF10B981),
                      icono: Icons.euro_rounded,
                      iconColor: const Color(0xFF60A5FA),
                      bordeColor: Colors.white10,
                      showTrendIcon: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockScreen(onChanged: _refrescarTodo))),
                      child: _kpiTarjeta(
                        titulo: 'Valor Stock',
                        valor: '${valorStock.toStringAsFixed(2)} €',
                        subtitulo: 'En inventario activo',
                        subColor: Colors.grey[400]!,
                        icono: Icons.view_in_ar_rounded,
                        iconColor: const Color(0xFF60A5FA),
                        bordeColor: Colors.white10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockScreen(onChanged: _refrescarTodo))),
                      child: _kpiTarjeta(
                        titulo: 'Stock Bajo',
                        valor: '$stockBajoCount Prod.',
                        subtitulo: 'Requieren reposición',
                        subColor: const Color(0xFFF59E0B),
                        icono: Icons.error_outline_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        bordeColor: Colors.white10,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF121927),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_none_rounded, color: Color(0xFFF59E0B), size: 20),
                            SizedBox(width: 8),
                            Text('Próximos Vencimientos de Cobro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => mostrarDialogoVenta(context, _refrescarTodo, esCreditoDefault: true),
                          child: const Text('+ Nuevo', style: TextStyle(fontSize: 12, color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (vencimientosProximos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('Sin cobros pendientes. ¡Todo al día!', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      )
                    else
                      ...vencimientosProximos.take(4).map((v) {
                        final dias = (v['dias_retraso'] as int?) ?? 0;
                        final esVencida = dias > 0;
                        final esHoy = dias == 0;
                        final textoBadge = esVencida
                            ? 'Vencida por $dias días'
                            : (esHoy ? '¡Vence Hoy!' : 'Vence en ${dias.abs()} días');
                        final colorBadge = esVencida
                            ? const Color(0xFFEF4444)
                            : (esHoy ? const Color(0xFFF59E0B) : const Color(0xFF60A5FA));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF182132),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      '${v['cliente_proveedor']} (${v['producto_nombre']})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorBadge.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(textoBadge, style: TextStyle(fontSize: 11, color: colorBadge, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(v['importe'] as num).toStringAsFixed(2)} €',
                                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final db = await DatabaseHelper.instance.database;
                                      await db.update(
                                        'movimientos',
                                        {'tipo': 'VENTA', 'estado_cobro': 'Pagado'},
                                        where: 'id = ?',
                                        whereArgs: [v['id']],
                                      );
                                      _refrescarTodo();
                                    },
                                    child: const Text('Cobrar ✓', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121927),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rendimiento de Ventas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('Ingresos vs Cuentas cobradas', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B263B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2F81F7).withOpacity(0.5)),
                          ),
                          child: const Text('EUR (€)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: LineChartPainter(valores: puntosGrafica, etiquetas: etiquetasMeses),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Movimientos & Kardex', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => mostrarDialogoVenta(context, _refrescarTodo),
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                        label: const Text('Venta', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: () => mostrarDialogoCompra(context, _refrescarTodo),
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF60A5FA)),
                        label: const Text('Compra', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['TODOS', 'VENTA', 'COMPRA', 'COBRO'].map((f) {
                    final sel = filtroKardex == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: sel,
                        selectedColor: const Color(0xFF2F81F7),
                        backgroundColor: const Color(0xFF121927),
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 12),
                        onSelected: (_) => setState(() => filtroKardex = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              if (movsFiltrados.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF121927), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const Text('Pulsa + arriba a la derecha para crear productos y registrar operaciones.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
              else
                ...movsFiltrados.map((m) {
                  final tipo = (m['tipo'] ?? '').toString().toUpperCase();
                  final esCompra = tipo == 'COMPRA';
                  final cant = m['cantidad'] ?? 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121927),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${m['cliente_proveedor']} • ${m['producto_nombre']} (x$cant)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 3),
                              Text('$tipo • ${m['tarifa']} • ${m['metodo_pago']} • ${m['fecha']}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(
                          '${esCompra ? '-' : '+'}${(m['importe'] as num).toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: esCompra ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                          onPressed: () async {
                            final db = await DatabaseHelper.instance.database;
                            await db.delete('movimientos', where: 'id = ?', whereArgs: [m['id']]);
                            _refrescarTodo();
                          },
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiTarjeta({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color subColor,
    required IconData icono,
    required Color iconColor,
    required Color bordeColor,
    bool showWarningIcon = false,
    bool showTrendIcon = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121927),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bordeColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500)),
              Icon(icono, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(valor, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (showWarningIcon) ...[
                Icon(Icons.warning_amber_rounded, size: 13, color: subColor),
                const SizedBox(width: 4),
              ],
              if (showTrendIcon) ...[
                Icon(Icons.trending_up_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List valores;
  final List etiquetas;

  LineChartPainter({required this.valores, required this.etiquetas});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 42.0;
    final bottomPad = 24.0;
    final chartW = size.width - leftPad - 10;
    final chartH = size.height - bottomPad - 10;

    double maxVal = 100.0;
    for (var v in valores) {
      if ((v as double) > maxVal) maxVal = v;
    }

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final y = 10 + (chartH / 4) * i;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - 10, y), gridPaint);
      final labelVal = (maxVal * (1 - i / 4)).toInt();
      textPainter.text = TextSpan(text: '$labelVal', style: const TextStyle(color: Colors.grey, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    final stepX = chartW / (valores.length - 1);
    final linePath = Path();
    final fillPath = Path();
    List puntos = [];

    for (int i = 0; i < valores.length; i++) {
      final val = (valores[i] as double);
      final x = leftPad + stepX * i;
      final y = 10 + chartH - ((val / maxVal) * chartH);
      puntos.add(Offset(x, y));

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, 10 + chartH);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      textPainter.text = TextSpan(text: etiquetas[i].toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 10, 10 + chartH + 6));
    }

    fillPath.lineTo(leftPad + chartW, 10 + chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF2F81F7).withOpacity(0.32), const Color(0xFF2F81F7).withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(leftPad, 10, chartW, chartH));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF2F81F7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, linePaint);

    final dotFill = Paint()..color = const Color(0xFF121927);
    final dotStroke = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (var pt in puntos) {
      canvas.drawCircle(pt as Offset, 4.5, dotFill);
      canvas.drawCircle(pt, 4.5, dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StockScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const StockScreen({super.key, required this.onChanged});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List productos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('productos', orderBy: 'nombre ASC');
    if (mounted) setState(() => productos = res);
  }

  void _dialogoProducto([Map? prod]) {
    final nombreCtrl = TextEditingController(text: prod?['nombre'] ?? '');
    final stockCtrl = TextEditingController(text: (prod?['stock'] ?? 0).toString());
    final costoCtrl = TextEditingController(text: prod != null ? (prod['costo_compra'] as num).toStringAsFixed(2) : '');
    final pvpCtrl = TextEditingController(text: prod != null ? (prod['precio_pvp'] as num).toStringAsFixed(2) : '');
    final colabCtrl = TextEditingController(text: prod != null ? (prod['precio_colaborador'] as num).toStringAsFixed(2) : '');
    final provCtrl = TextEditingController(text: prod?['proveedor'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF23304A)),
        ),
        title: Text(
          prod == null ? 'Nuevo Producto' : 'Editar Producto',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del Producto')),
              const SizedBox(height: 12),
              TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Proveedor habitual')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock Actual'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: costoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Costo (€)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pvpCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio PVP (€)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: colabCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio Colab (€)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600)),
          ),
          _botonGuardarBusiness(
            texto: 'Guardar',
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              final data = {
                'nombre': nombre,
                'proveedor': provCtrl.text.trim(),
                'stock': int.tryParse(stockCtrl.text) ?? 0,
                'costo_compra': double.tryParse(costoCtrl.text.replaceAll(',', '.')) ?? 0.0,
                'precio_pvp': double.tryParse(pvpCtrl.text.replaceAll(',', '.')) ?? 0.0,
                'precio_colaborador': double.tryParse(colabCtrl.text.replaceAll(',', '.')) ?? 0.0,
              };
              final db = await DatabaseHelper.instance.database;
              if (prod == null) {
                await db.insert('productos', data);
              } else {
                await db.update('productos', data, where: 'id = ?', whereArgs: [prod['id']]);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _cargar();
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario & Tarifas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0F1A),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F81F7),
        onPressed: () => _dialogoProducto(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Text(
              'Toca el lápiz para editar PVP, Precio Colaborador o stock.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
          Expanded(
            child: productos.isEmpty
                ? const Center(child: Text('Pulsa + para añadir tus productos al inventario.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                    itemCount: productos.length,
                    itemBuilder: (context, i) {
                      final pr = productos[i];
                      final st = (pr['stock'] as int?) ?? 0;
                      final pvp = ((pr['precio_pvp'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                      final col = ((pr['precio_colaborador'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121927),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF23304A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B2436),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF60A5FA), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pr['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 10,
                                    children: [
                                      Text('PVP: $pvp €', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text('Especial Col.: $col €', style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text('Stock: $st uds', style: TextStyle(color: st <= 3 ? const Color(0xFFF59E0B) : Colors.grey[400], fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF60A5FA), size: 20),
                              onPressed: () => _dialogoProducto(pr),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                              onPressed: () async {
                                final db = await DatabaseHelper.instance.database;
                                await db.delete('productos', where: 'id = ?', whereArgs: [pr['id']]);
                                _cargar();
                                widget.onChanged();
                              },
                            ),
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
}

class ClientesScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ClientesScreen({super.key, required this.onChanged});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List clientes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('clientes', orderBy: 'nombre ASC');
    if (mounted) setState(() => clientes = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes & Colaboradores'), backgroundColor: const Color(0xFF0A0F1A)),
      body: clientes.isEmpty
          ? const Center(child: Text('Se guardarán solos cuando registres ventas.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: clientes.length,
              itemBuilder: (context, i) {
                final c = clientes[i];
                final esColab = c['tipo'] == 'Colaborador';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121927),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF23304A)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1B2436),
                      child: Icon(Icons.person, color: esColab ? const Color(0xFFEC4899) : const Color(0xFF60A5FA)),
                    ),
                    title: Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text('${c['tipo']}', style: TextStyle(color: esColab ? const Color(0xFFEC4899) : const Color(0xFF10B981), fontSize: 12)),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> mostrarDialogoVenta(BuildContext context, VoidCallback onSaved, {bool esCreditoDefault = false}) async {
  final db = await DatabaseHelper.instance.database;
  final productos = await db.query('productos', orderBy: 'nombre ASC');
  final clientes = await db.query('clientes', orderBy: 'nombre ASC');

  if (productos.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero crea un producto en Inventario & Tarifas (menú +).')));
    }
    return;
  }

  Map prodSel = productos.first;
  String tarifaSel = 'Cliente Final (PVP)';
  String metodoPago = esCreditoDefault ? 'Crédito / Fiado' : 'Contado / Efectivo';
  String estadoCobro = esCreditoDefault ? 'Pendiente' : 'Pagado';

  final cantidadCtrl = TextEditingController(text: '1');
  final clienteCtrl = TextEditingController();
  final totalCtrl = TextEditingController(text: ((prodSel['precio_pvp'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2));
  final vencCtrl = TextEditingController(text: DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T')[0]);

  void recalcularTotal() {
    final cant = int.tryParse(cantidadCtrl.text) ?? 1;
    final unit = tarifaSel.contains('Colab')
        ? ((prodSel['precio_colaborador'] as num?)?.toDouble() ?? 0.0)
        : ((prodSel['precio_pvp'] as num?)?.toDouble() ?? 0.0);
    totalCtrl.text = (cant * unit).toStringAsFixed(2);
  }

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDlg) => AlertDialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF23304A)),
        ),
        title: Text(
          esCreditoDefault ? 'Nueva Cuenta por Cobrar' : 'Registrar Nueva Venta',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: prodSel['id'] as int,
                isExpanded: true,
                dropdownColor: const Color(0xFF1B2436),
                decoration: const InputDecoration(labelText: 'Producto del Stock'),
                items: productos.map((pr) => DropdownMenuItem<int>(
                  value: pr['id'] as int,
                  child: Text('${pr['nombre']} (PVP ${pr['precio_pvp']}€ / Col ${pr['precio_colaborador']}€)', style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (id) => setStateDlg(() {
                  prodSel = productos.firstWhere((e) => e['id'] == id);
                  recalcularTotal();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clienteCtrl,
                decoration: InputDecoration(
                  labelText: 'Cliente / Colaborador',
                  hintText: 'Escribe o elige de la flecha',
                  suffixIcon: clientes.isEmpty
                      ? null
                      : PopupMenuButton<String>(
                          color: const Color(0xFF1B2436),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF60A5FA)),
                          onSelected: (nombreElegido) {
                            setStateDlg(() {
                              clienteCtrl.text = nombreElegido;
                              final encontrado = clientes.firstWhere((c) => c['nombre'] == nombreElegido, orElse: () => {});
                              tarifaSel = encontrado['tipo'] == 'Colaborador' ? 'Colaborador' : 'Cliente Final (PVP)';
                              recalcularTotal();
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            return clientes.map((c) {
                              final nom = c['nombre'].toString();
                              final tip = c['tipo'].toString();
                              return PopupMenuItem<String>(value: nom, child: Text('$nom ($tip)'));
                            }).toList();
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) => setStateDlg(() => recalcularTotal()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: tarifaSel,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1B2436),
                      decoration: const InputDecoration(labelText: 'Tarifa Aplicada'),
                      items: const [
                        DropdownMenuItem(value: 'Cliente Final (PVP)', child: Text('Cliente Final (PVP)')),
                        DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador')),
                      ],
                      onChanged: (val) => setStateDlg(() {
                        tarifaSel = val!;
                        recalcularTotal();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importe Total (€)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodoPago,
                isExpanded: true,
                dropdownColor: const Color(0xFF1B2436),
                decoration: const InputDecoration(labelText: 'Método de Pago'),
                items: const [
                  DropdownMenuItem(value: 'Contado / Efectivo', child: Text('Contado / Efectivo')),
                  DropdownMenuItem(value: 'Bizum', child: Text('Bizum')),
                  DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'Crédito / Fiado', child: Text('Crédito / Pendiente')),
                ],
                onChanged: (val) => setStateDlg(() {
                  metodoPago = val!;
                  estadoCobro = metodoPago.contains('Crédito') ? 'Pendiente' : 'Pagado';
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: estadoCobro,
                isExpanded: true,
                dropdownColor: const Color(0xFF1B2436),
                decoration: const InputDecoration(labelText: 'Estado del Cobro'),
                items: const [
                  DropdownMenuItem(value: 'Pagado', child: Text('Cobrado / Pagado')),
                  DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente de Cobro')),
                ],
                onChanged: (val) => setStateDlg(() => estadoCobro = val!),
              ),
              if (estadoCobro == 'Pendiente') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: vencCtrl,
                  decoration: const InputDecoration(labelText: 'Vencimiento (AAAA-MM-DD)'),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600)),
          ),
          _botonGuardarBusiness(
            texto: 'Guardar',
            onPressed: () async {
              final clienteNombre = clienteCtrl.text.trim().isEmpty ? 'Cliente General' : clienteCtrl.text.trim();
              final cant = int.tryParse(cantidadCtrl.text) ?? 1;
              final total = double.tryParse(totalCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final unit = cant > 0 ? total / cant : total;
              final fechaHoy = DateTime.now().toIso8601String().split('T')[0];

              await DatabaseHelper.instance.asegurarCliente(clienteNombre, tarifaSel);

              final stockActual = (prodSel['stock'] as int?) ?? 0;
              final nuevoStock = (stockActual - cant) < 0 ? 0 : (stockActual - cant);
              await db.update('productos', {'stock': nuevoStock}, where: 'id = ?', whereArgs: [prodSel['id']]);

              await db.insert('movimientos', {
                'tipo': 'VENTA',
                'producto_id': prodSel['id'],
                'producto_nombre': prodSel['nombre'],
                'cliente_proveedor': clienteNombre,
                'tarifa': tarifaSel.contains('Colab') ? 'Colaborador' : 'PVP',
                'cantidad': cant,
                'precio_unitario': unit,
                'importe': total,
                'metodo_pago': metodoPago,
                'estado_cobro': estadoCobro,
                'fecha': fechaHoy,
                'fecha_vencimiento': vencCtrl.text.trim().isEmpty ? fechaHoy : vencCtrl.text.trim(),
              });

              if (ctx.mounted) Navigator.pop(ctx);
              onSaved();
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> mostrarDialogoCompra(BuildContext context, VoidCallback onSaved) async {
  final db = await DatabaseHelper.instance.database;
  final productos = await db.query('productos', orderBy: 'nombre ASC');

  if (productos.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero crea el producto en Inventario & Tarifas (menú +).')));
    }
    return;
  }

  Map prodSel = productos.first;
  final provCtrl = TextEditingController(text: prodSel['proveedor']?.toString() ?? '');
  final cantidadCtrl = TextEditingController(text: '1');
  final costoUnitCtrl = TextEditingController(text: ((prodSel['costo_compra'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2));
  final totalCtrl = TextEditingController(text: costoUnitCtrl.text);

  void recalcularCompra() {
    final cant = int.tryParse(cantidadCtrl.text) ?? 1;
    final unit = double.tryParse(costoUnitCtrl.text.replaceAll(',', '.')) ?? 0.0;
    totalCtrl.text = (cant * unit).toStringAsFixed(2);
  }

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDlg) => AlertDialog(
        backgroundColor: const Color(0xFF121927),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF23304A)),
        ),
        title: const Text('Registrar Nueva Compra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: prodSel['id'] as int,
                isExpanded: true,
                dropdownColor: const Color(0xFF1B2436),
                decoration: const InputDecoration(labelText: 'Producto del Stock'),
                items: productos.map((pr) => DropdownMenuItem<int>(
                  value: pr['id'] as int,
                  child: Text('${pr['nombre']} (Stock: ${pr['stock']})', style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (id) => setStateDlg(() {
                  prodSel = productos.firstWhere((e) => e['id'] == id);
                  provCtrl.text = prodSel['proveedor']?.toString() ?? '';
                  costoUnitCtrl.text = ((prodSel['costo_compra'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                  recalcularCompra();
                }),
              ),
              const SizedBox(height: 12),
              TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Proveedor')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) => setStateDlg(() => recalcularCompra()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: costoUnitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Costo Unit. (€)'),
                      onChanged: (_) => setStateDlg(() => recalcularCompra()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total Compra (€)'),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600)),
          ),
          _botonGuardarBusiness(
            texto: 'Guardar Compra',
            onPressed: () async {
              final cant = int.tryParse(cantidadCtrl.text) ?? 1;
              final unit = double.tryParse(costoUnitCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final total = double.tryParse(totalCtrl.text.replaceAll(',', '.')) ?? (cant * unit);
              final prov = provCtrl.text.trim().isEmpty ? 'Proveedor General' : provCtrl.text.trim();
              final fechaHoy = DateTime.now().toIso8601String().split('T')[0];

              final stockActual = (prodSel['stock'] as int?) ?? 0;
              await db.update(
                'productos',
                {'stock': stockActual + cant, 'costo_compra': unit, 'proveedor': prov},
                where: 'id = ?',
                whereArgs: [prodSel['id']],
              );

              await db.insert('movimientos', {
                'tipo': 'COMPRA',
                'producto_id': prodSel['id'],
                'producto_nombre': prodSel['nombre'],
                'cliente_proveedor': prov,
                'tarifa': 'Costo Proveedor',
                'cantidad': cant,
                'precio_unitario': unit,
                'importe': total,
                'metodo_pago': 'Contado / Transferencia',
                'estado_cobro': 'Pagado',
                'fecha': fechaHoy,
                'fecha_vencimiento': fechaHoy,
              });

              if (ctx.mounted) Navigator.pop(ctx);
              onSaved();
            },
          ),
        ],
      ),
    ),
  );
}
