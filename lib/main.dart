import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ERPJuanApp());
}

class _BusinessColors {
  static const bg = Color(0xFF0B0F17);
  static const card = Color(0xFF121926);
  static const surface = Color(0xFF182234);
  static const border = Color(0xFF233044);
  static const primaryBlue = Color(0xFF3B82F6);
  static const softBlue = Color(0xFF60A5FA);
  static const emerald = Color(0xFF10B981);
  static const emeraldBright = Color(0xFF34D399);
  static const amber = Color(0xFFD97706);
  static const amberSoft = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const textMain = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF94A3B8);
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
        scaffoldBackgroundColor: _BusinessColors.bg,
        primaryColor: _BusinessColors.primaryBlue,
        cardColor: _BusinessColors.card,
        dialogBackgroundColor: _BusinessColors.card,
        colorScheme: const ColorScheme.dark(
          primary: _BusinessColors.primaryBlue,
          secondary: _BusinessColors.emerald,
          surface: _BusinessColors.card,
          error: _BusinessColors.danger,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _BusinessColors.surface,
          labelStyle: const TextStyle(color: _BusinessColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _BusinessColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _BusinessColors.primaryBlue, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _BusinessColors.border),
          ),
        ),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('erp_juan_v5.db');
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
        costo_total REAL NOT NULL DEFAULT 0.0,
        metodo_pago TEXT DEFAULT 'Efectivo',
        estado_cobro TEXT DEFAULT 'Pagado',
        notas TEXT DEFAULT '',
        fecha TEXT NOT NULL,
        fecha_vencimiento TEXT NOT NULL
      )
    ''');
  }

  Future<void> asegurarContacto(String nombre, String tipo) async {
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
        'tipo': tipo,
        'telefono': '',
      });
    }
  }
}

String _fmtEur(double val) => '${val.toStringAsFixed(2).replaceAll('.', ',')} €';

String _fechaCortaEs(String iso) {
  final partes = iso.split('-');
  if (partes.length == 3) return '${partes[2]}/${partes[1]}/${partes[0]}';
  return iso;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _refreshTick = 0;
  String _filtroKardexInicial = 'TODOS';
  bool _soloStockBajoInicial = false;

  void _notificarCambio() {
    setState(() => _refreshTick++);
  }

  void _irAPestana(int idx, {String? filtroKardex, bool? soloStockBajo}) {
    setState(() {
      _index = idx;
      if (filtroKardex != null) _filtroKardexInicial = filtroKardex;
      if (soloStockBajo != null) _soloStockBajoInicial = soloStockBajo;
      _refreshTick++;
    });
  }

  Future<void> _abrirNuevaVentaPantalla() async {
    final guardada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NuevaVentaScreen()),
    );
    if (guardada == true) _notificarCambio();
  }

  Future<void> _abrirNuevaCompraDialog() async {
    final guardada = await mostrarDialogoCompra(context);
    if (guardada == true) _notificarCambio();
  }

  void _mostrarCalculadoraMargenes() {
    final costoCtrl = TextEditingController(text: '10,00');
    final pvpCtrl = TextEditingController(text: '25,00');
    final colabCtrl = TextEditingController(text: '18,00');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          double parse(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;
          final c = parse(costoCtrl.text);
          final pvp = parse(pvpCtrl.text);
          final col = parse(colabCtrl.text);
          final benPvp = pvp - c;
          final pctPvp = pvp > 0 ? ((benPvp / pvp) * 100) : 0.0;
          final benCol = col - c;
          final pctCol = col > 0 ? ((benCol / col) * 100) : 0.0;

          return AlertDialog(
            backgroundColor: _BusinessColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _BusinessColors.border),
            ),
            title: const Text('Calculadora de Márgenes PVP / Colab', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: costoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Coste unitario (€)'),
                    onChanged: (_) => setDlg(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pvpCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Precio PVP (€)'),
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: colabCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Precio Colab. (€)'),
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _BusinessColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _BusinessColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PVP: +${_fmtEur(benPvp)} (${pctPvp.toStringAsFixed(1).replaceAll('.', ',')} %)',
                          style: const TextStyle(color: _BusinessColors.emeraldBright, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Colaborador: +${_fmtEur(benCol)} (${pctCol.toStringAsFixed(1).replaceAll('.', ',')} %)',
                          style: const TextStyle(color: _BusinessColors.softBlue, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar', style: TextStyle(color: _BusinessColors.softBlue, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirMenuMas() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _BusinessColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _BusinessColors.border),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Acciones & Módulos ERP Juan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _BusinessColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('Nueva Venta', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _abrirNuevaVentaPantalla();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _BusinessColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.inventory_rounded, size: 18),
                    label: const Text('Nueva Compra', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _abrirNuevaCompraDialog();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: _BusinessColors.softBlue),
              title: const Text('Inventario & Tarifas', style: TextStyle(color: _BusinessColors.textMain, fontWeight: FontWeight.w600)),
              subtitle: const Text('Productos, precios PVP / Especial Colaborador y stock', style: TextStyle(color: _BusinessColors.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _irAPestana(2, soloStockBajo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined, color: _BusinessColors.emeraldBright),
              title: const Text('Clientes & Colaboradores', style: TextStyle(color: _BusinessColors.textMain, fontWeight: FontWeight.w600)),
              subtitle: const Text('Base de datos autorrellenable y tarifas', style: TextStyle(color: _BusinessColors.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _irAPestana(5);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined, color: _BusinessColors.amberSoft),
              title: const Text('Calculadora de Márgenes PVP / Colab', style: TextStyle(color: _BusinessColors.textMain, fontWeight: FontWeight.w600)),
              subtitle: const Text('Simula precios y beneficios unitarios', style: TextStyle(color: _BusinessColors.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarCalculadoraMargenes();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      DashboardScreen(
        key: ValueKey('dash_$_refreshTick'),
        onChanged: _notificarCambio,
        onAbrirMenuMas: _abrirMenuMas,
        onIrPestana: _irAPestana,
      ),
      VentasScreen(
        key: ValueKey('ventas_$_refreshTick'),
        onChanged: _notificarCambio,
        onNuevaVenta: _abrirNuevaVentaPantalla,
      ),
      StockScreen(
        key: ValueKey('stock_$_refreshTick'),
        onChanged: _notificarCambio,
        onNuevaCompra: _abrirNuevaCompraDialog,
        soloStockBajoInicial: _soloStockBajoInicial,
      ),
      CobrosScreen(
        key: ValueKey('cobros_$_refreshTick'),
        onChanged: _notificarCambio,
        onNuevaVenta: _abrirNuevaVentaPantalla,
      ),
      KardexScreen(
        key: ValueKey('kardex_$_refreshTick'),
        onChanged: _notificarCambio,
        onNuevaVenta: _abrirNuevaVentaPantalla,
        onNuevaCompra: _abrirNuevaCompraDialog,
        filtroInicial: _filtroKardexInicial,
      ),
      ClientesScreen(
        key: ValueKey('clientes_$_refreshTick'),
        onChanged: _notificarCambio,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pantallas[_index]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _BusinessColors.card,
          border: Border(top: BorderSide(color: _BusinessColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          backgroundColor: _BusinessColors.card,
          selectedItemColor: _BusinessColors.softBlue,
          unselectedItemColor: _BusinessColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (i) => _irAPestana(i, filtroKardex: 'TODOS', soloStockBajo: false),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Ventas'),
            BottomNavigationBarItem(icon: Icon(Icons.sell_outlined), label: 'Stock'),
            BottomNavigationBarItem(icon: Icon(Icons.schedule_rounded), label: 'Cobros'),
            BottomNavigationBarItem(icon: Icon(Icons.swap_vert_rounded), label: 'Kardex'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Clientes'),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onChanged;
  final VoidCallback onAbrirMenuMas;
  final void Function(int idx, {String? filtroKardex, bool? soloStockBajo}) onIrPestana;

  const DashboardScreen({
    super.key,
    required this.onChanged,
    required this.onAbrirMenuMas,
    required this.onIrPestana,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String periodo = 'Este mes';
  double porCobrar = 0.0;
  double vencidoMonto = 0.0;
  int vencidasCount = 0;
  double ingresos = 0.0;
  double comprasPeriodo = 0.0;
  double margenBruto = 0.0;
  double valorStock = 0.0;
  int stockBajoCount = 0;
  int ventasCount = 0;
  int comprasCount = 0;

  List vencimientos = [];
  List barrasMeses = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  bool _dentroDePeriodo(String fechaStr, DateTime hoy) {
    final f = DateTime.tryParse(fechaStr);
    if (f == null) return true;
    final fDia = DateTime(f.year, f.month, f.day);
    final hDia = DateTime(hoy.year, hoy.month, hoy.day);
    if (periodo == 'Hoy') return fDia == hDia;
    if (periodo == 'Esta semana') return hDia.difference(fDia).inDays >= 0 && hDia.difference(fDia).inDays <= 7;
    if (periodo == 'Este año') return f.year == hoy.year;
    return f.year == hoy.year && f.month == hoy.month;
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final movs = await db.query('movimientos', orderBy: 'id DESC');
    final prods = await db.query('productos');

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    double pCob = 0.0;
    double vMonto = 0.0;
    int vCnt = 0;
    double ing = 0.0;
    double comp = 0.0;
    double mBruto = 0.0;
    int vOps = 0;
    int cOps = 0;
    List listaVenc = [];

    List clavesMes = [];
    List etiquetas = [];
    const mesesNom = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(ahora.year, ahora.month - i, 1);
      clavesMes.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
      etiquetas.add(mesesNom[d.month - 1]);
    }
    List ventasMes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    List comprasMes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

    for (var m in movs) {
      final tipo = (m['tipo'] ?? '').toString().toUpperCase();
      final imp = (m['importe'] as num?)?.toDouble() ?? 0.0;
      final costo = (m['costo_total'] as num?)?.toDouble() ?? 0.0;
      final estado = (m['estado_cobro'] ?? 'Pagado').toString();
      final fechaStr = (m['fecha'] ?? '').toString();
      final vencStr = (m['fecha_vencimiento'] ?? fechaStr).toString();

      if (tipo == 'VENTA' || tipo == 'COBRO') {
        if (estado == 'Pendiente') {
          pCob += imp;
          final fv = DateTime.tryParse(vencStr) ?? hoy;
          final diasRetraso = hoy.difference(DateTime(fv.year, fv.month, fv.day)).inDays;
          if (diasRetraso > 0) {
            vCnt++;
            vMonto += imp;
          }
          final copia = Map.from(m);
          copia['dias_retraso'] = diasRetraso;
          listaVenc.add(copia);
        } else {
          if (_dentroDePeriodo(fechaStr, hoy)) {
            ing += imp;
            mBruto += (imp - costo);
            vOps++;
          }
          for (int k = 0; k < 6; k++) {
            if (fechaStr.startsWith(clavesMes[k])) {
              ventasMes[k] = (ventasMes[k] as double) + imp;
            }
          }
        }
      } else if (tipo == 'COMPRA') {
        if (_dentroDePeriodo(fechaStr, hoy)) {
          comp += imp;
          cOps++;
        }
        for (int k = 0; k < 6; k++) {
          if (fechaStr.startsWith(clavesMes[k])) {
            comprasMes[k] = (comprasMes[k] as double) + imp;
          }
        }
      }
    }

    double vStock = 0.0;
    int sBajo = 0;
    for (var pr in prods) {
      final st = (pr['stock'] as int?) ?? 0;
      final cUnit = (pr['costo_compra'] as num?)?.toDouble() ?? 0.0;
      vStock += st * cUnit;
      if (st <= 3) sBajo++;
    }

    List barras = [];
    for (int k = 0; k < 6; k++) {
      barras.add({
        'mes': etiquetas[k],
        'ventas': ventasMes[k],
        'compras': comprasMes[k],
      });
    }

    if (mounted) {
      setState(() {
        porCobrar = pCob;
        vencidoMonto = vMonto;
        vencidasCount = vCnt;
        ingresos = ing;
        comprasPeriodo = comp;
        margenBruto = mBruto;
        valorStock = vStock;
        stockBajoCount = sBajo;
        ventasCount = vOps;
        comprasCount = cOps;
        vencimientos = listaVenc;
        barrasMeses = barras;
      });
    }
  }

  Future<void> _exportarResumen() async {
    final sb = StringBuffer();
    sb.writeln('ERP JUAN — Panel ($periodo)');
    sb.writeln('Ingresos: ${_fmtEur(ingresos)}');
    sb.writeln('Por cobrar: ${_fmtEur(porCobrar)} ($vencidasCount vencidas)');
    sb.writeln('Compras: ${_fmtEur(comprasPeriodo)} ($comprasCount órdenes)');
    sb.writeln('Valor stock: ${_fmtEur(valorStock)} ($stockBajoCount stock bajo)');
    sb.writeln('Margen bruto: ${_fmtEur(margenBruto)}');
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: _BusinessColors.emerald, content: Text('Resumen copiado al portapapeles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final horaFmt = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}';

    double maxBarra = 100.0;
    for (var b in barrasMeses) {
      final bv = (b['ventas'] as double);
      final bc = (b['compras'] as double);
      if (bv > maxBarra) maxBarra = bv;
      if (bc > maxBarra) maxBarra = bc;
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: _BusinessColors.primaryBlue, borderRadius: BorderRadius.circular(12)),
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
                        const Text('ERP Juan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _BusinessColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _BusinessColors.primaryBlue.withOpacity(0.45)),
                          ),
                          child: const Text('BUSINESS UI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _BusinessColors.softBlue)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('EN VIVO $horaFmt · $ventasCount ventas · $comprasCount compras', style: const TextStyle(fontSize: 11, color: _BusinessColors.emeraldBright, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: _BusinessColors.textMuted), onPressed: _cargar),
              GestureDetector(
                onTap: widget.onAbrirMenuMas,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: _BusinessColors.primaryBlue, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Este mes', 'Esta semana', 'Hoy', 'Este año'].map((pItem) {
                final sel = periodo == pItem;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(pItem),
                    selected: sel,
                    selectedColor: _BusinessColors.primaryBlue,
                    backgroundColor: _BusinessColors.card,
                    side: BorderSide(color: sel ? _BusinessColors.primaryBlue : _BusinessColors.border),
                    labelStyle: TextStyle(color: sel ? Colors.white : _BusinessColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
                    onSelected: (_) {
                      setState(() => periodo = pItem);
                      _cargar();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => widget.onIrPestana(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A151E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _BusinessColors.danger.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: _BusinessColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$vencidasCount Deuda(s) Vencida(s) · Cobrar ${_fmtEur(porCobrar)}',
                      style: const TextStyle(fontSize: 12, color: _BusinessColors.textMain, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: _exportarResumen,
                    child: const Row(
                      children: [
                        Icon(Icons.download_rounded, color: _BusinessColors.softBlue, size: 16),
                        SizedBox(width: 4),
                        Text('Exportar', style: TextStyle(fontSize: 12, color: _BusinessColors.softBlue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _tarjetaKpi(
                  titulo: 'Por Cobrar',
                  valor: _fmtEur(porCobrar),
                  subtitulo: '$vencidasCount Vencidas (${_fmtEur(vencidoMonto)})',
                  subColor: _BusinessColors.danger,
                  badgeAccion: 'Cobros',
                  accentColor: _BusinessColors.danger,
                  onTap: () => widget.onIrPestana(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaKpi(
                  titulo: 'Ingresos',
                  valor: _fmtEur(ingresos),
                  subtitulo: '$ventasCount ventas cobradas',
                  subColor: _BusinessColors.emeraldBright,
                  badgeAccion: 'Ventas',
                  accentColor: _BusinessColors.emerald,
                  onTap: () => widget.onIrPestana(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tarjetaKpi(
                  titulo: 'Valor Stock',
                  valor: _fmtEur(valorStock),
                  subtitulo: 'En inventario activo',
                  subColor: _BusinessColors.textMuted,
                  badgeAccion: 'Stock',
                  accentColor: _BusinessColors.primaryBlue,
                  onTap: () => widget.onIrPestana(2, soloStockBajo: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaKpi(
                  titulo: 'Stock Bajo',
                  valor: '$stockBajoCount Prod.',
                  subtitulo: 'Requieren reposición',
                  subColor: _BusinessColors.amberSoft,
                  badgeAccion: 'Reponer',
                  accentColor: _BusinessColors.amberSoft,
                  onTap: () => widget.onIrPestana(2, soloStockBajo: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tarjetaKpi(
                  titulo: 'Margen Bruto',
                  valor: _fmtEur(margenBruto),
                  subtitulo: 'Ventas - Coste producto',
                  subColor: _BusinessColors.softBlue,
                  badgeAccion: 'Kardex',
                  accentColor: _BusinessColors.softBlue,
                  onTap: () => widget.onIrPestana(4, filtroKardex: 'VENTA'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaKpi(
                  titulo: 'Compras',
                  valor: _fmtEur(comprasPeriodo),
                  subtitulo: '$comprasCount órdenes proveedor',
                  subColor: _BusinessColors.amberSoft,
                  badgeAccion: 'Compras',
                  accentColor: _BusinessColors.amber,
                  onTap: () => widget.onIrPestana(4, filtroKardex: 'COMPRA'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _BusinessColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _BusinessColors.amber.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_none_rounded, color: _BusinessColors.amberSoft, size: 19),
                        SizedBox(width: 8),
                        Text('Próximos Vencimientos de Cobro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _BusinessColors.amberSoft)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => widget.onIrPestana(3),
                      child: const Text('Ver Todo', style: TextStyle(fontSize: 12, color: _BusinessColors.softBlue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (vencimientos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _BusinessColors.surface, borderRadius: BorderRadius.circular(10)),
                    child: const Text('No hay cobros pendientes.', style: TextStyle(color: _BusinessColors.textMuted, fontSize: 12)),
                  )
                else
                  ...vencimientos.take(3).map((v) {
                    final dias = (v['dias_retraso'] as int?) ?? 0;
                    final badge = dias > 0 ? 'Venció hace $dias días' : (dias == 0 ? 'Vence hoy' : 'Vence ${_fechaCortaEs(v['fecha_vencimiento'].toString())}');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _BusinessColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _BusinessColors.border)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${v['cliente_proveedor']}', style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain, fontSize: 13)),
                                Text('${v['producto_nombre']} · $badge', style: TextStyle(color: dias > 0 ? _BusinessColors.danger : _BusinessColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(_fmtEur((v['importe'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _BusinessColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _BusinessColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ventas vs Compras — últimos 6 meses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
                const SizedBox(height: 3),
                const Text('Se actualiza al crear una venta o compra.', style: TextStyle(fontSize: 11, color: _BusinessColors.textMuted)),
                const SizedBox(height: 14),
                ...barrasMeses.map((b) {
                  final mes = b['mes'].toString();
                  final vVal = (b['ventas'] as double);
                  final cVal = (b['compras'] as double);
                  final vFrac = (vVal / maxBarra).clamp(0.02, 1.0);
                  final cFrac = (cVal / maxBarra).clamp(0.02, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: 36, child: Text(mes, style: const TextStyle(color: _BusinessColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FractionallySizedBox(
                                widthFactor: vFrac,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: _BusinessColors.primaryBlue, borderRadius: BorderRadius.circular(6)),
                                  child: Text('Ventas ${vVal.toStringAsFixed(0)} €', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FractionallySizedBox(
                                widthFactor: cFrac,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: _BusinessColors.amber, borderRadius: BorderRadius.circular(6)),
                                  child: Text('Compras ${cVal.toStringAsFixed(0)} €', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaKpi({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color subColor,
    required String badgeAccion,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _BusinessColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _BusinessColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _BusinessColors.textMuted)),
                  Text('$badgeAccion →', style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
              const SizedBox(height: 5),
              Text(subtitulo, style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> mostrarDialogoCompra(BuildContext context) async {
  final db = await DatabaseHelper.instance.database;
  final productos = await db.query('productos', orderBy: 'nombre ASC');

  if (productos.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero crea un producto en Stock para registrar compras.')),
      );
    }
    return false;
  }

  Map prodSel = productos.first;
  final provCtrl = TextEditingController(text: prodSel['proveedor']?.toString() ?? '');
  final cantCtrl = TextEditingController(text: '1');
  final costoUnitCtrl = TextEditingController(
    text: ((prodSel['costo_compra'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ','),
  );
  final totalCtrl = TextEditingController(text: costoUnitCtrl.text);
  String metodoPago = 'Transferencia';
  String fechaIso = DateTime.now().toIso8601String().split('T')[0];

  double parseNum(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  void recalcularTotal() {
    final c = int.tryParse(cantCtrl.text.trim()) ?? 1;
    final u = parseNum(costoUnitCtrl.text);
    totalCtrl.text = (c * u).toStringAsFixed(2).replaceAll('.', ',');
  }

  if (!context.mounted) return false;

  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: _BusinessColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _BusinessColors.border),
        ),
        title: const Text('Registrar Nueva Compra', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: prodSel['id'] as int,
                isExpanded: true,
                dropdownColor: _BusinessColors.surface,
                decoration: const InputDecoration(labelText: 'Producto del Stock'),
                items: productos
                    .map((pr) => DropdownMenuItem<int>(
                          value: pr['id'] as int,
                          child: Text('${pr['nombre']} (Stock: ${pr['stock']})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setDlg(() {
                    prodSel = productos.firstWhere((e) => e['id'] == id);
                    provCtrl.text = prodSel['proveedor']?.toString() ?? '';
                    costoUnitCtrl.text = ((prodSel['costo_compra'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2).replaceAll('.', ',');
                    recalcularTotal();
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Proveedor')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) => setDlg(recalcularTotal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: costoUnitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Coste unit. (€)'),
                      onChanged: (_) => setDlg(recalcularTotal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: totalCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Total compra (€)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: metodoPago,
                      isExpanded: true,
                      dropdownColor: _BusinessColors.surface,
                      decoration: const InputDecoration(labelText: 'Método'),
                      items: const [
                        DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Bizum', child: Text('Bizum', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) => setDlg(() => metodoPago = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final inicial = DateTime.tryParse(fechaIso) ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: inicial,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2032),
                  );
                  if (picked != null) {
                    setDlg(() => fechaIso = picked.toIso8601String().split('T')[0]);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha de compra'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fechaCortaEs(fechaIso), style: const TextStyle(fontSize: 13, color: _BusinessColors.textMain)),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: _BusinessColors.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _BusinessColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _BusinessColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final cant = int.tryParse(cantCtrl.text.trim()) ?? 1;
              final unit = parseNum(costoUnitCtrl.text);
              final total = parseNum(totalCtrl.text) > 0 ? parseNum(totalCtrl.text) : (cant * unit);
              final prov = provCtrl.text.trim().isEmpty ? 'Proveedor General' : provCtrl.text.trim();

              final stActual = (prodSel['stock'] as int?) ?? 0;
              await db.update(
                'productos',
                {'stock': stActual + cant, 'costo_compra': unit > 0 ? unit : (prodSel['costo_compra'] ?? 0.0), 'proveedor': prov},
                where: 'id = ?',
                whereArgs: [prodSel['id']],
              );

              await db.insert('movimientos', {
                'tipo': 'COMPRA',
                'producto_id': prodSel['id'],
                'producto_nombre': prodSel['nombre'],
                'cliente_proveedor': prov,
                'tarifa': 'Coste Proveedor',
                'cantidad': cant,
                'precio_unitario': cant > 0 ? total / cant : unit,
                'importe': total,
                'costo_total': total,
                'metodo_pago': metodoPago,
                'estado_cobro': 'Pagado',
                'notas': '',
                'fecha': fechaIso,
                'fecha_vencimiento': fechaIso,
              });

              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar compra', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );

  return resultado == true;
}

class NuevaVentaScreen extends StatefulWidget {
  const NuevaVentaScreen({super.key});

  @override
  State<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

class _LineaVentaDraft {
  Map? producto;
  final TextEditingController cantCtrl;
  final TextEditingController precioCtrl;

  _LineaVentaDraft({this.producto, String cant = '1', String precio = '0,00'})
      : cantCtrl = TextEditingController(text: cant),
        precioCtrl = TextEditingController(text: precio);

  void dispose() {
    cantCtrl.dispose();
    precioCtrl.dispose();
  }
}

class _NuevaVentaScreenState extends State<NuevaVentaScreen> {
  List productos = [];
  List clientes = [];
  String clienteSeleccionado = 'Cliente General';
  String fechaIso = DateTime.now().toIso8601String().split('T')[0];
  String fechaVencIso = DateTime.now().add(const Duration(days: 15)).toIso8601String().split('T')[0];

  final List<_LineaVentaDraft> lineas = [];
  final descuentoCtrl = TextEditingController(text: '0');
  final ivaCtrl = TextEditingController(text: '21');
  final notasCtrl = TextEditingController();
  String metodoPago = 'Efectivo';
  bool cobradoEnElActo = true;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    for (var l in lineas) {
      l.dispose();
    }
    descuentoCtrl.dispose();
    ivaCtrl.dispose();
    notasCtrl.dispose();
    super.dispose();
  }

  double _precioSegunContacto(Map pr) {
    final esColab = clienteSeleccionado.toLowerCase().contains('colaborador') ||
        clientes.any((c) => c['nombre'] == clienteSeleccionado && c['tipo'].toString().toLowerCase().contains('colab'));
    if (esColab) {
      return (pr['precio_colaborador'] as num?)?.toDouble() ?? 0.0;
    }
    return (pr['precio_pvp'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _cargarDatos() async {
    final db = await DatabaseHelper.instance.database;
    final prods = await db.query('productos', orderBy: 'nombre ASC');
    final clis = await db.query('clientes', orderBy: 'nombre ASC');

    setState(() {
      productos = prods;
      clientes = clis;
      if (lineas.isEmpty && prods.isNotEmpty) {
        final primero = prods.first;
        lineas.add(_LineaVentaDraft(
          producto: primero,
          cant: '1',
          precio: _precioSegunContacto(primero).toStringAsFixed(2).replaceAll('.', ','),
        ));
      }
      cargando = false;
    });
  }

  void _actualizarPreciosPorCliente() {
    for (var l in lineas) {
      if (l.producto != null) {
        final pUnit = _precioSegunContacto(l.producto!);
        l.precioCtrl.text = pUnit.toStringAsFixed(2).replaceAll('.', ',');
      }
    }
    setState(() {});
  }

  void _anadirLinea() {
    if (productos.isEmpty) return;
    final pr = productos.first;
    setState(() {
      lineas.add(_LineaVentaDraft(
        producto: pr,
        cant: '1',
        precio: _precioSegunContacto(pr).toStringAsFixed(2).replaceAll('.', ','),
      ));
    });
  }

  Future<void> _dialogoNuevoContacto() async {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String tipoSel = 'Cliente Final';

    final creado = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _BusinessColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _BusinessColors.border)),
          title: const Text('Nuevo contacto', style: TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre o empresa')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: tipoSel,
                dropdownColor: _BusinessColors.surface,
                decoration: const InputDecoration(labelText: 'Tipo de contacto'),
                items: const [
                  DropdownMenuItem(value: 'Cliente Final', child: Text('Cliente Final (PVP)')),
                  DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador (Tarifa Colab.)')),
                ],
                onChanged: (v) => setDlg(() => tipoSel = v!),
              ),
              const SizedBox(height: 10),
              TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: _BusinessColors.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _BusinessColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () async {
                final nom = nombreCtrl.text.trim();
                if (nom.isEmpty) return;
                final db = await DatabaseHelper.instance.database;
                await db.insert(
                  'clientes',
                  {'nombre': nom, 'tipo': tipoSel, 'telefono': telCtrl.text.trim()},
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                if (ctx.mounted) Navigator.pop(ctx, nom);
              },
              child: const Text('Guardar contacto', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (creado != null) {
      await _cargarDatos();
      setState(() {
        clienteSeleccionado = creado;
        _actualizarPreciosPorCliente();
      });
    }
  }

  Future<void> _elegirFecha(bool esVencimiento) async {
    final baseStr = esVencimiento ? fechaVencIso : fechaIso;
    final inicial = DateTime.tryParse(baseStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (picked != null) {
      final iso = picked.toIso8601String().split('T')[0];
      setState(() {
        if (esVencimiento) {
          fechaVencIso = iso;
        } else {
          fechaIso = iso;
        }
      });
    }
  }

  double _parseNum(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  double get _subtotalBruto {
    double sum = 0.0;
    for (var l in lineas) {
      final c = int.tryParse(l.cantCtrl.text.trim()) ?? 0;
      final p = _parseNum(l.precioCtrl.text);
      sum += c * p;
    }
    return sum;
  }

  double get _descuento => _parseNum(descuentoCtrl.text);
  double get _baseImponible => (_subtotalBruto - _descuento) < 0 ? 0.0 : (_subtotalBruto - _descuento);
  double get _ivaPct => _parseNum(ivaCtrl.text);
  double get _importeIva => _baseImponible * (_ivaPct / 100.0);
  double get _totalFinal => _baseImponible + _importeIva;

  double get _margenEstimado {
    double costoLineas = 0.0;
    for (var l in lineas) {
      final c = int.tryParse(l.cantCtrl.text.trim()) ?? 0;
      final costoU = (l.producto?['costo_compra'] as num?)?.toDouble() ?? 0.0;
      costoLineas += c * costoU;
    }
    return _baseImponible - costoLineas;
  }

  Future<void> _guardarVenta() async {
    if (lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Añade al menos una línea de producto')));
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final tipoCli = clientes.firstWhere(
      (c) => c['nombre'] == clienteSeleccionado,
      orElse: () => {'tipo': 'Cliente Final'},
    )['tipo'].toString();
    await DatabaseHelper.instance.asegurarContacto(clienteSeleccionado, tipoCli);

    final estadoCobro = cobradoEnElActo ? 'Pagado' : 'Pendiente';
    final vencFinal = cobradoEnElActo ? fechaIso : fechaVencIso;
    final factorDesc = _subtotalBruto > 0 ? (_baseImponible / _subtotalBruto) : 1.0;

    for (var l in lineas) {
      final pr = l.producto;
      if (pr == null) continue;
      final cant = int.tryParse(l.cantCtrl.text.trim()) ?? 1;
      final precioU = _parseNum(l.precioCtrl.text);
      final impLinea = (cant * precioU) * factorDesc * (1 + (_ivaPct / 100.0));
      final costoU = (pr['costo_compra'] as num?)?.toDouble() ?? 0.0;

      final stActual = (pr['stock'] as int?) ?? 0;
      final stNuevo = (stActual - cant) < 0 ? 0 : (stActual - cant);
      await db.update('productos', {'stock': stNuevo}, where: 'id = ?', whereArgs: [pr['id']]);

      await db.insert('movimientos', {
        'tipo': 'VENTA',
        'producto_id': pr['id'],
        'producto_nombre': pr['nombre'],
        'cliente_proveedor': clienteSeleccionado,
        'tarifa': tipoCli.contains('Colab') ? 'Colaborador' : 'PVP',
        'cantidad': cant,
        'precio_unitario': precioU,
        'importe': impLinea,
        'costo_total': cant * costoU,
        'metodo_pago': metodoPago,
        'estado_cobro': estadoCobro,
        'notas': notasCtrl.text.trim(),
        'fecha': fechaIso,
        'fecha_vencimiento': vencFinal,
      });
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final opcionesCliente = [
      'Cliente General',
      ...clientes.map((c) => c['nombre'].toString()).where((n) => n != 'Cliente General'),
    ];
    if (!opcionesCliente.contains(clienteSeleccionado)) {
      opcionesCliente.add(clienteSeleccionado);
    }

    return Scaffold(
      backgroundColor: _BusinessColors.bg,
      appBar: AppBar(
        backgroundColor: _BusinessColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Nueva venta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _BusinessColors.textMuted,
                side: const BorderSide(color: _BusinessColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Descartar'),
            ),
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _BusinessColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _BusinessColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cliente', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: clienteSeleccionado,
                                  isExpanded: true,
                                  dropdownColor: _BusinessColors.surface,
                                  items: opcionesCliente
                                      .map((nom) => DropdownMenuItem<String>(
                                            value: nom,
                                            child: Text(nom, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => clienteSeleccionado = val);
                                      _actualizarPreciosPorCliente();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Fecha', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _elegirFecha(false),
                                  borderRadius: BorderRadius.circular(10),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_fechaCortaEs(fechaIso), style: const TextStyle(fontSize: 13, color: _BusinessColors.textMain)),
                                        const Icon(Icons.keyboard_arrow_down, size: 18, color: _BusinessColors.textMuted),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _BusinessColors.textMain,
                          backgroundColor: _BusinessColors.surface,
                          side: const BorderSide(color: _BusinessColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _dialogoNuevoContacto,
                        child: const Text('+ Nuevo contacto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _BusinessColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _BusinessColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Líneas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
                      const SizedBox(height: 10),
                      if (productos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text('No hay productos creados. Ve a Stock para añadir productos.', style: TextStyle(color: _BusinessColors.amberSoft, fontSize: 12)),
                        )
                      else ...[
                        const Row(
                          children: [
                            Expanded(flex: 4, child: Text('Producto', style: TextStyle(fontSize: 11, color: _BusinessColors.textMuted))),
                            SizedBox(width: 6),
                            Expanded(flex: 2, child: Text('Cant.', style: TextStyle(fontSize: 11, color: _BusinessColors.textMuted))),
                            SizedBox(width: 6),
                            Expanded(flex: 3, child: Text('Precio', style: TextStyle(fontSize: 11, color: _BusinessColors.textMuted))),
                            SizedBox(width: 6),
                            Expanded(flex: 3, child: Text('Importe', style: TextStyle(fontSize: 11, color: _BusinessColors.textMuted))),
                            SizedBox(width: 24),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...lineas.map((l) {
                          final cant = int.tryParse(l.cantCtrl.text.trim()) ?? 0;
                          final prU = _parseNum(l.precioCtrl.text);
                          final impL = cant * prU;
                          final prodIdActual = l.producto?['id'] as int?;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: DropdownButtonFormField<int>(
                                    value: prodIdActual,
                                    isExpanded: true,
                                    dropdownColor: _BusinessColors.surface,
                                    items: productos
                                        .map((pItem) => DropdownMenuItem<int>(
                                              value: pItem['id'] as int,
                                              child: Text(pItem['nombre'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                            ))
                                        .toList(),
                                    onChanged: (id) {
                                      if (id == null) return;
                                      final elegido = productos.firstWhere((e) => e['id'] == id);
                                      setState(() {
                                        l.producto = elegido;
                                        l.precioCtrl.text = _precioSegunContacto(elegido).toStringAsFixed(2).replaceAll('.', ',');
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: l.cantCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: l.precioCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 12),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _fmtEur(impL),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _BusinessColors.textMain),
                                  ),
                                ),
                                SizedBox(
                                  width: 24,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.close, size: 16, color: _BusinessColors.textMuted),
                                    onPressed: () {
                                      setState(() {
                                        l.dispose();
                                        lineas.remove(l);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 4),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _BusinessColors.textMain,
                          backgroundColor: _BusinessColors.surface,
                          side: const BorderSide(color: _BusinessColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _anadirLinea,
                        child: const Text('+ Añadir producto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _BusinessColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _BusinessColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Descuento (€)', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: descuentoCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('IVA %', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: ivaCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Método', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: metodoPago,
                                  isExpanded: true,
                                  dropdownColor: _BusinessColors.surface,
                                  items: const [
                                    DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Bizum', child: Text('Bizum', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia', style: TextStyle(fontSize: 12))),
                                  ],
                                  onChanged: (v) => setState(() => metodoPago = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Checkbox(
                            value: cobradoEnElActo,
                            activeColor: _BusinessColors.primaryBlue,
                            onChanged: (v) => setState(() => cobradoEnElActo = v ?? true),
                          ),
                          const Text('Cobrado en el acto', style: TextStyle(fontSize: 13, color: _BusinessColors.textMain)),
                        ],
                      ),

                      if (!cobradoEnElActo) ...[
                        const SizedBox(height: 6),
                        const Text('Fecha de vencimiento', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _elegirFecha(true),
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_fechaCortaEs(fechaVencIso), style: const TextStyle(fontSize: 13, color: _BusinessColors.textMain)),
                                const Icon(Icons.keyboard_arrow_down, size: 18, color: _BusinessColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      const Text('Notas', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notasCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(hintText: 'Observaciones de envío, entrega o cobro...'),
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: _BusinessColors.border),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(color: _BusinessColors.textMuted, fontSize: 13)),
                          Text(_fmtEur(_baseImponible), style: const TextStyle(color: _BusinessColors.textMain, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('IVA ${_ivaPct.toStringAsFixed(0)}%', style: const TextStyle(color: _BusinessColors.textMuted, fontSize: 13)),
                          Text(_fmtEur(_importeIva), style: const TextStyle(color: _BusinessColors.textMain, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(color: _BusinessColors.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(_fmtEur(_totalFinal), style: const TextStyle(color: _BusinessColors.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Margen estimado', style: TextStyle(color: _BusinessColors.textMuted, fontSize: 12)),
                          Text(_fmtEur(_margenEstimado), style: const TextStyle(color: _BusinessColors.emeraldBright, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _BusinessColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _guardarVenta,
                    child: const Text('Guardar venta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}

class VentasScreen extends StatefulWidget {
  final VoidCallback onChanged;
  final Future<void> Function() onNuevaVenta;

  const VentasScreen({super.key, required this.onChanged, required this.onNuevaVenta});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  List ventas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'movimientos',
      where: "tipo = 'VENTA' OR tipo = 'COBRO'",
      orderBy: 'id DESC',
    );
    if (mounted) setState(() => ventas = res);
  }

  @override
  Widget build(BuildContext context) {
    double totalVentas = 0.0;
    for (var v in ventas) {
      totalVentas += (v['importe'] as num?)?.toDouble() ?? 0.0;
    }

    return Scaffold(
      backgroundColor: _BusinessColors.bg,
      appBar: AppBar(
        backgroundColor: _BusinessColors.bg,
        title: const Text('Ventas & Cobros', style: TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _BusinessColors.emerald, foregroundColor: Colors.white),
              onPressed: () async {
                await widget.onNuevaVenta();
                _cargar();
                widget.onChanged();
              },
              child: const Text('+ Nueva venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _BusinessColors.border)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total registrado', style: TextStyle(color: _BusinessColors.textMuted)),
                Text(_fmtEur(totalVentas), style: const TextStyle(color: _BusinessColors.emeraldBright, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ventas.isEmpty
                ? const Center(child: Text('Aún no hay ventas registradas.', style: TextStyle(color: _BusinessColors.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: ventas.length,
                    itemBuilder: (ctx, i) {
                      final v = ventas[i];
                      final pend = (v['estado_cobro'] ?? '') == 'Pendiente';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _BusinessColors.border)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${v['cliente_proveedor']} · ${v['producto_nombre']} (x${v['cantidad'] ?? 1})', style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
                                  Text('${_fechaCortaEs(v['fecha'].toString())} · ${v['metodo_pago']} · ${pend ? 'Pendiente' : 'Pagado'}', style: TextStyle(color: pend ? _BusinessColors.amberSoft : _BusinessColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(_fmtEur((v['importe'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain, fontSize: 14)),
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

class StockScreen extends StatefulWidget {
  final VoidCallback onChanged;
  final Future<void> Function() onNuevaCompra;
  final bool soloStockBajoInicial;

  const StockScreen({
    super.key,
    required this.onChanged,
    required this.onNuevaCompra,
    this.soloStockBajoInicial = false,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List todosProductos = [];
  String busqueda = '';
  late bool soloBajo;

  @override
  void initState() {
    super.initState();
    soloBajo = widget.soloStockBajoInicial;
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('productos', orderBy: 'nombre ASC');
    if (mounted) setState(() => todosProductos = res);
  }

  void _dialogoProducto([Map? prod]) {
    final nombreCtrl = TextEditingController(text: prod?['nombre'] ?? '');
    final provCtrl = TextEditingController(text: prod?['proveedor'] ?? '');
    final stockCtrl = TextEditingController(text: (prod?['stock'] ?? 0).toString());
    final costoCtrl = TextEditingController(text: prod != null ? ((prod['costo_compra'] as num).toDouble().toStringAsFixed(2).replaceAll('.', ',')) : '0,00');
    final pvpCtrl = TextEditingController(text: prod != null ? ((prod['precio_pvp'] as num).toDouble().toStringAsFixed(2).replaceAll('.', ',')) : '0,00');
    final colabCtrl = TextEditingController(text: prod != null ? ((prod['precio_colaborador'] as num).toDouble().toStringAsFixed(2).replaceAll('.', ',')) : '0,00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _BusinessColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _BusinessColors.border)),
        title: Text(prod == null ? 'Nuevo producto' : 'Editar producto', style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del producto')),
              const SizedBox(height: 10),
              TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Proveedor habitual')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock (uds)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: costoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Coste (€)'))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: pvpCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'PVP (€)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: colabCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Colaborador (€)'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: _BusinessColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _BusinessColors.primaryBlue, foregroundColor: Colors.white),
            onPressed: () async {
              final nom = nombreCtrl.text.trim();
              if (nom.isEmpty) return;
              double pNum(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0.0;
              final data = {
                'nombre': nom,
                'proveedor': provCtrl.text.trim(),
                'stock': int.tryParse(stockCtrl.text.trim()) ?? 0,
                'costo_compra': pNum(costoCtrl),
                'precio_pvp': pNum(pvpCtrl),
                'precio_colaborador': pNum(colabCtrl),
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
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _dialogoAjustarStock(Map prod) {
    final cantCtrl = TextEditingController(text: '1');
    final provCtrl = TextEditingController(text: prod['proveedor']?.toString() ?? '');
    bool esEntrada = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _BusinessColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _BusinessColors.border)),
          title: Text('Ajustar stock · ${prod['nombre']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('+ Entrada / Compra'),
                      selected: esEntrada,
                      selectedColor: _BusinessColors.emerald,
                      onSelected: (_) => setDlg(() => esEntrada = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('- Salida / Ajuste'),
                      selected: !esEntrada,
                      selectedColor: _BusinessColors.danger,
                      onSelected: (_) => setDlg(() => esEntrada = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: cantCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unidades')),
              if (esEntrada) ...[
                const SizedBox(height: 10),
                TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Proveedor')),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: _BusinessColors.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _BusinessColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () async {
                final uds = int.tryParse(cantCtrl.text.trim()) ?? 0;
                if (uds <= 0) return;
                final stActual = (prod['stock'] as int?) ?? 0;
                final stNuevo = esEntrada ? (stActual + uds) : ((stActual - uds) < 0 ? 0 : (stActual - uds));
                final db = await DatabaseHelper.instance.database;
                await db.update('productos', {'stock': stNuevo}, where: 'id = ?', whereArgs: [prod['id']]);
                if (esEntrada) {
                  final costoU = (prod['costo_compra'] as num?)?.toDouble() ?? 0.0;
                  final hoy = DateTime.now().toIso8601String().split('T')[0];
                  await db.insert('movimientos', {
                    'tipo': 'COMPRA',
                    'producto_id': prod['id'],
                    'producto_nombre': prod['nombre'],
                    'cliente_proveedor': provCtrl.text.trim().isEmpty ? 'Proveedor General' : provCtrl.text.trim(),
                    'tarifa': 'Coste',
                    'cantidad': uds,
                    'precio_unitario': costoU,
                    'importe': uds * costoU,
                    'costo_total': uds * costoU,
                    'metodo_pago': 'Transferencia',
                    'estado_cobro': 'Pagado',
                    'notas': '',
                    'fecha': hoy,
                    'fecha_vencimiento': hoy,
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _cargar();
                widget.onChanged();
              },
              child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verHistorialProducto(Map prod) async {
    final db = await DatabaseHelper.instance.database;
    final hist = await db.query(
      'movimientos',
      where: 'producto_id = ? OR producto_nombre = ?',
      whereArgs: [prod['id'], prod['nombre']],
      orderBy: 'id DESC',
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _BusinessColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historial · ${prod['nombre']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
            const SizedBox(height: 12),
            if (hist.isEmpty)
              const Text('Sin movimientos registrados para este producto.', style: TextStyle(color: _BusinessColors.textMuted))
            else
              ...hist.take(8).map((m) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${m['tipo']} · ${m['cliente_proveedor']} (x${m['cantidad'] ?? 1})', style: const TextStyle(color: _BusinessColors.textMain)),
                    subtitle: Text('${_fechaCortaEs(m['fecha'].toString())} · ${m['estado_cobro']}', style: const TextStyle(color: _BusinessColors.textMuted, fontSize: 11)),
                    trailing: Text(_fmtEur((m['importe'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.emeraldBright)),
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double valTotal = 0.0;
    int bajos = 0;
    for (var pItem in todosProductos) {
      final st = (pItem['stock'] as int?) ?? 0;
      final cU = (pItem['costo_compra'] as num?)?.toDouble() ?? 0.0;
      valTotal += st * cU;
      if (st <= 3) bajos++;
    }

    final filtrados = todosProductos.where((pItem) {
      final nombre = (pItem['nombre'] ?? '').toString().toLowerCase();
      final prov = (pItem['proveedor'] ?? '').toString().toLowerCase();
      final q = busqueda.toLowerCase().trim();
      final pasaBusq = q.isEmpty || nombre.contains(q) || prov.contains(q);
      final pasaBajo = !soloBajo || (((pItem['stock'] as int?) ?? 0) <= 3);
      return pasaBusq && pasaBajo;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Inventario y tarifas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _BusinessColors.softBlue,
                    side: const BorderSide(color: _BusinessColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await widget.onNuevaCompra();
                    _cargar();
                    widget.onChanged();
                  },
                  child: const Text('+ Compra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _BusinessColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _dialogoProducto(),
                  child: const Text('+ Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(child: _miniKpiStock('Productos', '${todosProductos.length}', _BusinessColors.textMain, () => setState(() => soloBajo = false))),
            const SizedBox(width: 10),
            Expanded(child: _miniKpiStock('Valor inventario', _fmtEur(valTotal), _BusinessColors.textMain, () => setState(() => soloBajo = false))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _miniKpiStock('Stock bajo', '$bajos', _BusinessColors.danger, () => setState(() => soloBajo = !soloBajo))),
            const Expanded(child: SizedBox()),
          ],
        ),

        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => busqueda = v),
          decoration: const InputDecoration(hintText: 'Buscar producto o referencia...', prefixIcon: Icon(Icons.search, color: _BusinessColors.textMuted)),
        ),
        const SizedBox(height: 12),

        if (filtrados.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('No hay productos para mostrar.', style: TextStyle(color: _BusinessColors.textMuted)),
          )
        else
          ...filtrados.map((pr) {
            final st = (pr['stock'] as int?) ?? 0;
            final coste = (pr['costo_compra'] as num?)?.toDouble() ?? 0.0;
            final pvp = (pr['precio_pvp'] as num?)?.toDouble() ?? 0.0;
            final colab = (pr['precio_colaborador'] as num?)?.toDouble() ?? 0.0;
            final margenPct = pvp > 0 ? (((pvp - coste) / pvp) * 100) : 0.0;
            final esBajo = st <= 3;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _BusinessColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _BusinessColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(pr['nombre'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _BusinessColors.textMain))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: esBajo ? const Color(0xFF3A161B) : const Color(0xFF102E24),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$st uds',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: esBajo ? const Color(0xFFF87171) : _BusinessColors.emeraldBright),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Coste ${_fmtEur(coste)} · PVP ${_fmtEur(pvp)} · Colab. ${_fmtEur(colab)} · margen ${margenPct.toStringAsFixed(1).replaceAll('.', ',')} %',
                    style: const TextStyle(fontSize: 12, color: _BusinessColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _btnAccionStock('Ajustar', () => _dialogoAjustarStock(pr)),
                      const SizedBox(width: 8),
                      _btnAccionStock('Historial', () => _verHistorialProducto(pr)),
                      const SizedBox(width: 8),
                      _btnAccionStock('Editar', () => _dialogoProducto(pr)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: _BusinessColors.textMuted, size: 20),
                        onPressed: () async {
                          final db = await DatabaseHelper.instance.database;
                          await db.delete('productos', where: 'id = ?', whereArgs: [pr['id']]);
                          _cargar();
                          widget.onChanged();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _miniKpiStock(String titulo, String valor, Color colorValor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _BusinessColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
            const SizedBox(height: 6),
            Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorValor)),
          ],
        ),
      ),
    );
  }

  Widget _btnAccionStock(String texto, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _BusinessColors.textMain,
        backgroundColor: _BusinessColors.surface,
        side: const BorderSide(color: _BusinessColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      onPressed: onTap,
      child: Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class CobrosScreen extends StatefulWidget {
  final VoidCallback onChanged;
  final Future<void> Function() onNuevaVenta;

  const CobrosScreen({super.key, required this.onChanged, required this.onNuevaVenta});

  @override
  State<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends State<CobrosScreen> {
  String tabActiva = 'Me deben';
  List pendientes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'movimientos',
      where: "estado_cobro = 'Pendiente'",
      orderBy: 'fecha_vencimiento ASC',
    );
    if (mounted) setState(() => pendientes = res);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);

    double totalPend = 0.0;
    double totalVenc = 0.0;

    for (var pItem in pendientes) {
      final imp = (pItem['importe'] as num?)?.toDouble() ?? 0.0;
      totalPend += imp;
      final fv = DateTime.tryParse((pItem['fecha_vencimiento'] ?? '').toString()) ?? hoyDia;
      if (hoyDia.difference(DateTime(fv.year, fv.month, fv.day)).inDays > 0) {
        totalVenc += imp;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Cobros pendientes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _BusinessColors.emerald, foregroundColor: Colors.white),
              onPressed: () async {
                await widget.onNuevaVenta();
                _cargar();
                widget.onChanged();
              },
              child: const Text('+ Cobro', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: ['Me deben', 'Debo'].map((t) {
            final sel = tabActiva == t;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t),
                selected: sel,
                selectedColor: _BusinessColors.primaryBlue,
                backgroundColor: _BusinessColors.card,
                labelStyle: TextStyle(color: sel ? Colors.white : _BusinessColors.textMain, fontWeight: FontWeight.bold),
                onSelected: (_) => setState(() => tabActiva = t),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _BusinessColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total pendiente', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                    const SizedBox(height: 6),
                    Text(_fmtEur(tabActiva == 'Me deben' ? totalPend : 0.0), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _BusinessColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vencido', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
                    const SizedBox(height: 6),
                    Text(_fmtEur(tabActiva == 'Me deben' ? totalVenc : 0.0), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _BusinessColors.danger)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (tabActiva == 'Debo' || pendientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('No hay saldos pendientes en esta pestaña.', style: TextStyle(color: _BusinessColors.textMuted)),
          )
        else
          ...pendientes.map((c) {
            final imp = (c['importe'] as num?)?.toDouble() ?? 0.0;
            final fv = DateTime.tryParse((c['fecha_vencimiento'] ?? '').toString()) ?? hoyDia;
            final atraso = hoyDia.difference(DateTime(fv.year, fv.month, fv.day)).inDays;
            final estadoTexto = atraso > 0
                ? '⚠ venció ${_fechaCortaEs(c['fecha_vencimiento'].toString())}'
                : 'vence ${_fechaCortaEs(c['fecha_vencimiento'].toString())}';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _BusinessColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c['cliente_proveedor'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
                      Text(_fmtEur(imp), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${c['producto_nombre']} · $estadoTexto', style: TextStyle(fontSize: 12, color: atraso > 0 ? _BusinessColors.amberSoft : _BusinessColors.textMuted)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _BusinessColors.emerald, foregroundColor: Colors.white),
                        onPressed: () async {
                          final db = await DatabaseHelper.instance.database;
                          await db.update('movimientos', {'tipo': 'VENTA', 'estado_cobro': 'Pagado'}, where: 'id = ?', whereArgs: [c['id']]);
                          _cargar();
                          widget.onChanged();
                        },
                        child: const Text('Cobrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: _BusinessColors.textMain, backgroundColor: _BusinessColors.surface, side: const BorderSide(color: _BusinessColors.border)),
                        onPressed: () async {
                          final msg = 'Hola ${c['cliente_proveedor']}, te recordamos el cobro pendiente de ${_fmtEur(imp)} por ${c['producto_nombre']}.';
                          await Clipboard.setData(ClipboardData(text: msg));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recordatorio copiado para WhatsApp')));
                          }
                        },
                        child: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class KardexScreen extends StatefulWidget {
  final VoidCallback onChanged;
  final Future<void> Function() onNuevaVenta;
  final Future<void> Function() onNuevaCompra;
  final String filtroInicial;

  const KardexScreen({
    super.key,
    required this.onChanged,
    required this.onNuevaVenta,
    required this.onNuevaCompra,
    this.filtroInicial = 'TODOS',
  });

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  late String filtro;
  List movs = [];

  @override
  void initState() {
    super.initState();
    filtro = widget.filtroInicial;
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    List res = [];
    if (filtro == 'TODOS') {
      res = await db.query('movimientos', orderBy: 'id DESC');
    } else if (filtro == 'VENTA') {
      res = await db.query('movimientos', where: "tipo = 'VENTA' OR tipo = 'COBRO'", orderBy: 'id DESC');
    } else {
      res = await db.query('movimientos', where: 'tipo = ?', whereArgs: [filtro], orderBy: 'id DESC');
    }
    if (mounted) setState(() => movs = res);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kardex de movimientos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await widget.onNuevaVenta();
                      _cargar();
                      widget.onChanged();
                    },
                    child: const Text('+ Venta', style: TextStyle(color: _BusinessColors.emeraldBright, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await widget.onNuevaCompra();
                      _cargar();
                      widget.onChanged();
                    },
                    child: const Text('+ Compra', style: TextStyle(color: _BusinessColors.softBlue, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: ['TODOS', 'VENTA', 'COMPRA'].map((f) {
              final sel = filtro == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: sel,
                  selectedColor: _BusinessColors.primaryBlue,
                  backgroundColor: _BusinessColors.card,
                  labelStyle: TextStyle(color: sel ? Colors.white : _BusinessColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
                  onSelected: (_) {
                    setState(() => filtro = f);
                    _cargar();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: movs.isEmpty
              ? const Center(child: Text('Sin movimientos registrados.', style: TextStyle(color: _BusinessColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: movs.length,
                  itemBuilder: (ctx, i) {
                    final m = movs[i];
                    final esCompra = (m['tipo'] ?? '').toString().toUpperCase() == 'COMPRA';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _BusinessColors.border)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${m['cliente_proveedor']} · ${m['producto_nombre']} (x${m['cantidad'] ?? 1})', style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain, fontSize: 13)),
                                Text('${m['tipo']} · ${_fechaCortaEs(m['fecha'].toString())} · ${m['estado_cobro']}', style: const TextStyle(color: _BusinessColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(
                            '${esCompra ? '-' : '+'}${_fmtEur((m['importe'] as num).toDouble())}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: esCompra ? _BusinessColors.amberSoft : _BusinessColors.emeraldBright, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('Clientes y colaboradores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _BusinessColors.textMain)),
        const SizedBox(height: 6),
        const Text('Se añaden solos al crear contactos o registrar ventas.', style: TextStyle(fontSize: 12, color: _BusinessColors.textMuted)),
        const SizedBox(height: 14),
        if (clientes.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('Aún no hay contactos guardados.', style: TextStyle(color: _BusinessColors.textMuted)),
          )
        else
          ...clientes.map((c) {
            final esColab = (c['tipo'] ?? '').toString().toLowerCase().contains('colab');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _BusinessColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _BusinessColors.border)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _BusinessColors.surface,
                    child: Icon(Icons.person, color: esColab ? _BusinessColors.amberSoft : _BusinessColors.softBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: _BusinessColors.textMain, fontSize: 14)),
                        Text('${c['tipo']}${c['telefono'] != null && c['telefono'].toString().isNotEmpty ? ' · ${c['telefono']}' : ''}', style: TextStyle(color: esColab ? _BusinessColors.amberSoft : _BusinessColors.emeraldBright, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
