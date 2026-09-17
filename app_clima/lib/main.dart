import 'package:flutter/material.dart';

void main() {
  runApp(const AppClimaPrototype());
}

class AppClimaPrototype extends StatelessWidget {
  const AppClimaPrototype({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppClima',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B7F8C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F8),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int currentIndex = 0;

  final pages = const [WeatherPage(), RoutePage(), HistoryPage(), LearnPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Clima',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Rota',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historico',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Aprender',
          ),
        ],
      ),
    );
  }
}

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        PageHeader(title: 'Clima agora', subtitle: 'Sao Paulo, SP'),
        SizedBox(height: 20),
        CurrentWeatherCard(),
        SizedBox(height: 16),
        SectionTitle('Proximas horas'),
        SizedBox(height: 12),
        HourlyForecastList(),
        SizedBox(height: 20),
        SectionTitle('Indicadores'),
        SizedBox(height: 12),
        WeatherMetricGrid(),
      ],
    );
  }
}

class CurrentWeatherCard extends StatelessWidget {
  const CurrentWeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF12343B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_cloudy, color: Colors.white, size: 44),
              Spacer(),
              Text(
                '24 C',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            'Parcialmente nublado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Chance de chuva aumentando no fim da tarde.',
            style: TextStyle(color: Color(0xFFD7E6E8), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class HourlyForecastList extends StatelessWidget {
  const HourlyForecastList({super.key});

  static const items = [
    ForecastHour('Agora', Icons.cloud, '24 C', '18%'),
    ForecastHour('15:00', Icons.water_drop, '23 C', '42%'),
    ForecastHour('16:00', Icons.thunderstorm, '22 C', '68%'),
    ForecastHour('17:00', Icons.air, '21 C', '51%'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];

          return InfoCard(
            width: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.time,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Icon(item.icon, color: const Color(0xFF1B7F8C)),
                const SizedBox(height: 10),
                Text(item.temperature),
                Text('${item.rainChance} chuva'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WeatherMetricGrid extends StatelessWidget {
  const WeatherMetricGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        MetricTile(icon: Icons.water_drop, label: 'Chuva', value: '42%'),
        MetricTile(icon: Icons.air, label: 'Vento', value: '18 km/h'),
        MetricTile(icon: Icons.wb_sunny, label: 'UV', value: 'Alto'),
        MetricTile(
          icon: Icons.device_thermostat,
          label: 'Sensacao',
          value: '26 C',
        ),
      ],
    );
  }
}

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  TransportType selectedTransport = TransportType.walking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader(
          title: 'Rota com clima',
          subtitle: 'Padaria Central - 5 km',
        ),
        const SizedBox(height: 18),
        TransportSelector(
          selected: selectedTransport,
          onSelected: (transport) {
            setState(() => selectedTransport = transport);
          },
        ),
        const SizedBox(height: 18),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(selectedTransport.icon, color: const Color(0xFF1B7F8C)),
                  const SizedBox(width: 10),
                  Text(
                    selectedTransport.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    selectedTransport.duration,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                width: double.infinity,
                child: CustomPaint(
                  painter: RouteWeatherPainter(),
                  child: const Stack(
                    children: [
                      WeatherBubble(
                        left: 42,
                        top: 138,
                        icon: Icons.water_drop,
                        label: 'chuva',
                        color: Color(0xFF2F80ED),
                      ),
                      WeatherBubble(
                        left: 164,
                        top: 64,
                        icon: Icons.air,
                        label: 'vento',
                        color: Color(0xFF6C63FF),
                      ),
                      WeatherBubble(
                        right: 28,
                        top: 124,
                        icon: Icons.wb_sunny,
                        label: 'UV',
                        color: Color(0xFFE39D17),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Trechos coloridos indicam mudancas climaticas durante o caminho.',
                style: TextStyle(color: Color(0xFF5A6B70)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Alertas do trajeto'),
        const SizedBox(height: 12),
        const AlertTile(
          icon: Icons.water_drop,
          title: 'Chuva em 5 minutos',
          description: 'O trecho da Avenida Brasil pode ter chuva moderada.',
        ),
        const AlertTile(
          icon: Icons.air,
          title: 'Vento lateral',
          description: 'A regiao da ponte tem rajadas de vento.',
        ),
        const AlertTile(
          icon: Icons.wb_sunny,
          title: 'Radiacao alta',
          description: 'Use protecao solar se estiver caminhando ou pedalando.',
        ),
      ],
    );
  }
}

class TransportSelector extends StatelessWidget {
  const TransportSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final TransportType selected;
  final ValueChanged<TransportType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TransportType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final transport = TransportType.values[index];
          final isSelected = selected == transport;

          return ChoiceChip(
            selected: isSelected,
            avatar: Icon(transport.icon, size: 18),
            label: Text(transport.label),
            onSelected: (_) => onSelected(transport),
          );
        },
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        PageHeader(
          title: 'Historico',
          subtitle: 'Pesquisas salvas neste aparelho',
        ),
        SizedBox(height: 18),
        SearchFieldMock(),
        SizedBox(height: 18),
        HistoryTile(
          place: 'Padaria Central',
          detail: 'Caminhada - 10 min - risco de chuva',
          icon: Icons.bakery_dining,
        ),
        HistoryTile(
          place: 'Faculdade',
          detail: 'Carro - 22 min - vento moderado',
          icon: Icons.school,
        ),
        HistoryTile(
          place: 'Parque Municipal',
          detail: 'Bicicleta - 18 min - UV alto',
          icon: Icons.park,
        ),
      ],
    );
  }
}

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        PageHeader(
          title: 'Aprender',
          subtitle: 'Conceitos que aparecem neste prototipo',
        ),
        SizedBox(height: 18),
        LearnTile(
          title: 'Widget',
          description: 'Cada parte da tela em Flutter e um widget.',
        ),
        LearnTile(
          title: 'State',
          description:
              'O transporte selecionado muda a tela, entao fica no estado.',
        ),
        LearnTile(
          title: 'API',
          description:
              'Na versao real, clima e rota virao de servicos externos.',
        ),
        LearnTile(
          title: 'Historico local',
          description: 'Pesquisas podem ser salvas no celular sem criar login.',
        ),
      ],
    );
  }
}

class RouteWeatherPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(30, size.height - 44)
      ..cubicTo(78, 174, 96, 118, 142, 132)
      ..cubicTo(196, 150, 194, 52, 246, 54)
      ..cubicTo(298, 56, 306, 144, size.width - 34, 102);

    routePaint.color = const Color(0xFF7BB661);
    canvas.drawPath(path, routePaint);

    routePaint.color = const Color(0xFF2F80ED);
    canvas.drawLine(
      Offset(74, size.height - 98),
      const Offset(128, 132),
      routePaint,
    );

    routePaint.color = const Color(0xFF6C63FF);
    canvas.drawLine(const Offset(172, 120), const Offset(222, 62), routePaint);

    routePaint.color = const Color(0xFFE39D17);
    canvas.drawLine(
      const Offset(280, 64),
      Offset(size.width - 44, 102),
      routePaint,
    );

    final markerPaint = Paint()..color = const Color(0xFF12343B);
    canvas.drawCircle(Offset(30, size.height - 44), 10, markerPaint);
    canvas.drawCircle(Offset(size.width - 34, 102), 10, markerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WeatherBubble extends StatelessWidget {
  const WeatherBubble({
    required this.icon,
    required this.label,
    required this.color,
    this.left,
    this.right,
    this.top,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double? left;
  final double? right;
  final double? top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF12343B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 16, color: Color(0xFF5A6B70)),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF12343B),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.child, this.width, super.key});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAEC)),
      ),
      child: child,
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      width: 156,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1B7F8C)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF5A6B70))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class AlertTile extends StatelessWidget {
  const AlertTile({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1B7F8C)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Color(0xFF5A6B70)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    required this.place,
    required this.detail,
    required this.icon,
    super.key,
  });

  final String place;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1B7F8C)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(color: Color(0xFF5A6B70)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class LearnTile extends StatelessWidget {
  const LearnTile({required this.title, required this.description, super.key});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: Color(0xFF5A6B70))),
          ],
        ),
      ),
    );
  }
}

class SearchFieldMock extends StatelessWidget {
  const SearchFieldMock({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Buscar cidade ou destino',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1EAEC)),
        ),
      ),
    );
  }
}

class ForecastHour {
  const ForecastHour(this.time, this.icon, this.temperature, this.rainChance);

  final String time;
  final IconData icon;
  final String temperature;
  final String rainChance;
}

enum TransportType {
  walking('Caminhada', '10 min', Icons.directions_walk),
  bike('Bicicleta', '6 min', Icons.directions_bike),
  motorcycle('Moto', '4 min', Icons.two_wheeler),
  car('Carro', '5 min', Icons.directions_car);

  const TransportType(this.label, this.duration, this.icon);

  final String label;
  final String duration;
  final IconData icon;
}
