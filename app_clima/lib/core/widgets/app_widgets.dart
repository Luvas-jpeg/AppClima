import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF12343B))),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 16, color: Color(0xFF5A6B70))),
        ],
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF12343B)));
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.child, this.width, super.key});
  final Widget child;
  final double? width;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE1EAEC))),
        child: child,
      );
}

class MetricTile extends StatelessWidget {
  const MetricTile({required this.icon, required this.label, required this.value, super.key});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => InfoCard(
        width: 156,
        child: Row(children: [
          Icon(icon, color: const Color(0xFF1B7F8C)), const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Color(0xFF5A6B70))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ]),
      );
}

class AlertTile extends StatelessWidget {
  const AlertTile({required this.icon, required this.title, required this.description, super.key});
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InfoCard(child: Row(children: [
          Icon(icon, color: const Color(0xFF1B7F8C)), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: Color(0xFF5A6B70))),
          ])),
        ])),
      );
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({required this.place, required this.detail, required this.icon, super.key});
  final String place;
  final String detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InfoCard(child: Row(children: [
          Icon(icon, color: const Color(0xFF1B7F8C)), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: Color(0xFF5A6B70))),
          ])), const Icon(Icons.chevron_right),
        ])),
      );
}

class SearchFieldMock extends StatelessWidget {
  const SearchFieldMock({super.key});
  @override
  Widget build(BuildContext context) => TextField(
        decoration: InputDecoration(hintText: 'Buscar cidade ou destino', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE1EAEC)))),
      );
}

class WeatherErrorCard extends StatelessWidget {
  const WeatherErrorCard({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => InfoCard(child: Row(children: [
        const Icon(Icons.info_outline, color: Color(0xFF1B7F8C)), const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF5A6B70)))),
      ]));
}
