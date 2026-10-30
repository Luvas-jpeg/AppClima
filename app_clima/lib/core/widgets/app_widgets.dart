import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
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

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Color(0xFF12343B),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.child, this.width, super.key});
  final Widget child;
  final double? width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE1EAEC)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.width = 156,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final double width;
  @override
  Widget build(BuildContext context) => InfoCard(
    width: width,
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF1B7F8C)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF5A6B70)),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Padding(
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

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    required this.place,
    required this.detail,
    required this.icon,
    this.onTap,
    super.key,
  });
  final String place;
  final String detail;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
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
            Icon(onTap == null ? Icons.history : Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class WeatherErrorCard extends StatelessWidget {
  const WeatherErrorCard({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => InfoCard(
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Color(0xFF1B7F8C)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF5A6B70)),
          ),
        ),
      ],
    ),
  );
}

class JourneyActionCard extends StatelessWidget {
  const JourneyActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.primary = false,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : const Color(0xFF12343B);
    return Material(
      color: primary ? const Color(0xFF087F8C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: primary ? Colors.transparent : const Color(0xFFE1EAEC),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFFE8F4F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: foreground, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: primary
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF5A6B70),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: foreground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
