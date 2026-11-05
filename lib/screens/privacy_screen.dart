import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/icons.dart';
import '../core/privacy_policy.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// The privacy policy, built into the app so it works offline.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Screen(
      header: const AppHeader(title: 'Privacy policy', subtitle: 'Last updated $privacyPolicyUpdated'),
      children: [
        // Summary: the four promises, at a glance.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(appIcon('shield-checkmark-outline'), size: 22, color: c.primary),
                  const SizedBox(width: 10),
                  const Expanded(child: T('Your data stays private', v: TV.h3)),
                ],
              ),
              const SizedBox(height: 16),
              for (final (icon, text) in privacyHighlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(appIcon(icon), size: 18, color: c.primary),
                      const SizedBox(width: 12),
                      Expanded(child: T(text, v: TV.body, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Paragraph(privacyPolicyIntro),
                for (final (icon, title, paragraphs) in privacyPolicySections) ...[
                  const SizedBox(height: 22),
                  const HairDivider(),
                  const SizedBox(height: 22),
                  _Section(icon: icon, title: title, paragraphs: paragraphs),
                ],
                if (AppInfo.supportEmail.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const HairDivider(),
                  const SizedBox(height: 22),
                  _Section(
                    icon: 'mail-outline',
                    title: 'Contact',
                    paragraphs: ['Questions about this policy? Email ${AppInfo.supportEmail}'],
                  ),
                ],
              ],
            ),
          ),
        ),
        const Center(child: T('Last updated $privacyPolicyUpdated', v: TV.caption, faint: true)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.paragraphs});
  final String icon, title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBadge(icon: icon, color: c.primary, size: 36),
            const SizedBox(width: 12),
            Expanded(child: T(title, v: TV.h3)),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) SizedBox(height: paragraphs[i].startsWith('• ') ? 10 : 12),
          paragraphs[i].startsWith('• ') ? _Bullet(paragraphs[i].substring(2)) : _Paragraph(paragraphs[i]),
        ],
      ],
    );
  }
}

/// Body text with relaxed line spacing for easy reading.
class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: textStyle(TV.body).copyWith(color: context.colors.textMuted, height: 1.6, fontWeight: FontWeight.w400),
  );
}

/// "• Term: explanation" with the term in bold.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final split = text.indexOf(': ');
    final base = textStyle(TV.body).copyWith(color: c.textMuted, height: 1.6, fontWeight: FontWeight.w400);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9, right: 12, left: 4),
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
        ),
        Expanded(
          child: Text.rich(
            split < 0
                ? TextSpan(text: text)
                : TextSpan(
                    children: [
                      TextSpan(
                        text: text.substring(0, split),
                        style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: text.substring(split)),
                    ],
                  ),
            style: base,
          ),
        ),
      ],
    );
  }
}
