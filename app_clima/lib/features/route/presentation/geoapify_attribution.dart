import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GeoapifyAttribution extends StatelessWidget {
  const GeoapifyAttribution({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => TextButton(
    style: compact
        ? TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(48, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 10),
          )
        : null,
    onPressed: () async {
      try {
        final opened = await launchUrl(Uri.parse('https://www.geoapify.com/'));
        if (opened || !context.mounted) return;
      } catch (_) {
        if (!context.mounted) return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visite https://www.geoapify.com/')),
        );
      }
    },
    child: const Text(
      'Powered by Geoapify • © OpenStreetMap contributors',
      textAlign: TextAlign.center,
    ),
  );
}
