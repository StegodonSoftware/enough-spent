import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _contactEmail = 'enoughspent@stegodonsoftware.com';
const _emailSubject = 'Enough Spent. - App Feedback';

/// Shows the first-step review prompt dialog.
///
/// Returns true if the user is happy (wants to rate), false if not, null if
/// dismissed without action.
Future<bool?> showReviewPromptDialog(BuildContext context, int milestone) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Loving Enough Spent?'),
      content: Text(
        "You've tracked $milestone expenses! If Enough Spent. is helping you stay on top of your spending, a quick rating really helps us grow.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not really'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Yes! Rate us'),
        ),
      ],
    ),
  );
}

/// Shows a follow-up bottom sheet for users who said they're not happy.
///
/// Offers them the chance to send feedback via email without forcing them to.
Future<void> showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Thanks for the feedback',
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Want to help us improve?',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _launchFeedbackEmail(context);
              },
              child: const Text('Send feedback'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('No thanks'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _launchFeedbackEmail(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: _contactEmail,
    query: 'subject=${Uri.encodeComponent(_emailSubject)}',
  );
  if (!await launchUrl(uri)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
