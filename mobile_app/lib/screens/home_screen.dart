import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'productos/productos_screen.dart';
import 'clientes/clientes_screen.dart';
import 'inventario/inventario_screen.dart';
import 'compras/compras_screen.dart';
import 'ventas/ventas_screen.dart';
import 'ia/ia_chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: 28),
                _buildIaBanner(context),
                const SizedBox(height: 28),
                Text(
                  'Módulos ERP',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8A8AA0),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                _buildModulosGrid(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: const Color(0xFF13131F),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2447), Color(0xFF2AB7CA)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dashboard_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            'ERP Serverless',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF072033),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2AB7CA).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2AB7CA),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AWS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2AB7CA),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenido 👋',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF8A8AA0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Panel de Control',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.2, end: 0, duration: 400.ms);
  }

  Widget _buildIaBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IaChatScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B2447), Color(0xFF2AB7CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2447).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '✨ Modelo Gemma 2B',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Asistente IA\npara tu ERP',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escribe en lenguaje natural y el modelo genera las acciones del ERP',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      const Icon(Icons.smart_toy_rounded, size: 16, color: Color(0xFF0B2447)),
                      const SizedBox(width: 8),
                      Text(
                        'Agente ReAct IA',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B2447),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 38, color: Colors.white),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms);
  }

  Widget _buildModulosGrid(BuildContext context) {
    final modulos = [
      _ModuloItem(
        icon: Icons.inventory_2_rounded,
        label: 'Productos',
        desc: 'CRUD completo',
        color: const Color(0xFF3498DB),
        screen: const ProductosScreen(),
      ),
      _ModuloItem(
        icon: Icons.people_alt_rounded,
        label: 'Clientes',
        desc: 'Gestión de clientes',
        color: const Color(0xFF2ECC71),
        screen: const ClientesScreen(),
      ),
      _ModuloItem(
        icon: Icons.warehouse_rounded,
        label: 'Inventario',
        desc: 'Stock y alertas',
        color: const Color(0xFFE67E22),
        screen: const InventarioScreen(),
      ),
      _ModuloItem(
        icon: Icons.shopping_cart_rounded,
        label: 'Compras',
        desc: 'Órdenes de compra',
        color: const Color(0xFF9B59B6),
        screen: const ComprasScreen(),
      ),
      _ModuloItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Ventas',
        desc: 'Registro de ventas',
        color: const Color(0xFFE74C3C),
        screen: const VentasScreen(),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.1,
      ),
      itemCount: modulos.length,
      itemBuilder: (context, i) {
        final m = modulos[i];
        return _ModuloCard(item: m)
            .animate()
            .fadeIn(delay: (100 * i).ms, duration: 300.ms)
            .slideY(begin: 0.3, end: 0, duration: 300.ms);
      },
    );
  }
}

class _ModuloItem {
  final IconData icon;
  final String label;
  final String desc;
  final Color color;
  final Widget screen;

  _ModuloItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.screen,
  });
}

class _ModuloCard extends StatelessWidget {
  final _ModuloItem item;
  const _ModuloCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item.screen),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: item.color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const Spacer(),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.desc,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF8A8AA0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
