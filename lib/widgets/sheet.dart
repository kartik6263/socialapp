import 'package:flutter/material.dart' hide Card, Chip, Switch, Banner;

import '../api/client.dart' show ApiError;
import '../i18n/i18n.dart';
import '../nav.dart';
import 'ui.dart';

/// Bottom sheet over a dimmed screen. Returns when it closes.
Future<T?> showSheet<T>(BuildContext context, {String? label, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: Nav.rootKey.currentContext ?? context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color.fromRGBO(15, 25, 23, 0.4),
    barrierLabel: tr('Close'),
    builder: (ctx) => SheetFrame(label: label, child: builder(ctx)),
  );
}

class SheetFrame extends StatelessWidget {
  final String? label;
  final Widget child;
  const SheetFrame({super.key, this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: label,
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
          // Sheets and dialogs float over a dimmed screen, so they stay nearly opaque to keep text contrast.
          decoration: BoxDecoration(
            color: const Color.fromRGBO(247, 250, 247, 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: GlassTokens.border),
          ),
          padding: EdgeInsets.only(left: 18, right: 18, top: 10, bottom: mq.padding.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: const Color.fromRGBO(24, 35, 33, 0.18), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Flexible(child: SingleChildScrollView(physics: const ClampingScrollPhysics(), child: child)),
          ]),
        ),
      ),
    );
  }
}

class SheetAction {
  final String label;
  final IconName icon;
  final String? sub;
  final bool danger;
  final VoidCallback onPress;
  const SheetAction(this.label, this.icon, this.onPress, {this.sub, this.danger = false});
}

/// "⋯" menus: Report / Block / Mute etc. Closes before running the action.
Future<void> showActionSheet(BuildContext context, {required String title, String? sub, String? quote, required List<SheetAction> actions}) async {
  SheetAction? chosen;
  await showSheet<void>(
    context,
    label: title,
    builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Txt(title, variant: TV.heading),
      if (sub != null && sub.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            const FIcon('link', size: 12, color: AppColors.inkSoft),
            const SizedBox(width: 5),
            Expanded(child: Txt(sub, variant: TV.small)),
          ]),
        ),
      if (quote != null && quote.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Text('“$quote”',
              style: const TextStyle(fontFamily: Fonts.body, fontStyle: FontStyle.italic, fontSize: 13, color: AppColors.inkSoft)),
        ),
      Container(
        margin: const EdgeInsets.only(top: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < actions.length; i++)
            Pressable(
              onPress: () {
                chosen = actions[i];
                Navigator.of(ctx).pop();
              },
              label: actions[i].sub != null ? '${actions[i].label}, ${actions[i].sub}' : actions[i].label,
              focusRadius: BorderRadius.zero,
              builder: (_, pressed, _) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pressed ? AppColors.paper : null,
                  border: i > 0 ? const Border(top: BorderSide(color: AppColors.divider)) : null,
                ),
                child: Row(children: [
                  FIcon(actions[i].icon, size: 19, color: actions[i].danger ? AppColors.danger : AppColors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(actions[i].label,
                          style: TextStyle(fontFamily: Fonts.bodyBold, fontSize: 14, color: actions[i].danger ? AppColors.danger : AppColors.ink)),
                      if (actions[i].sub != null) Txt(actions[i].sub, variant: TV.small),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Button(tr('Cancel'), kind: BK.secondary, onPress: () => Navigator.of(ctx).pop()),
    ]),
  );
  final c = chosen;
  if (c != null) await Future<void>.delayed(const Duration(milliseconds: 250), c.onPress);
}

/// Centered confirmation dialog (block, unblock, sign out, deactivate…).
/// Runs `onConfirm` with a busy state; an error keeps the dialog open and is shown inside it.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String okLabel,
  String? cancelLabel,
  required Future<void> Function() onConfirm,
  IconName icon = 'alert-circle',
  PillTone tone = PillTone.ok,
  BK okKind = BK.primary,
}) async {
  final ok = await showGeneralDialog<bool>(
    context: Nav.rootKey.currentContext ?? context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: const Color.fromRGBO(15, 25, 23, 0.45),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    pageBuilder: (ctx, _, _) => _ConfirmDialog(
      title: title,
      body: body,
      okLabel: okLabel,
      cancelLabel: cancelLabel ?? tr('Cancel'),
      onConfirm: onConfirm,
      icon: icon,
      tone: tone,
      okKind: okKind,
    ),
  );
  return ok == true;
}

class _ConfirmDialog extends StatefulWidget {
  final String title, body, okLabel, cancelLabel;
  final Future<void> Function() onConfirm;
  final IconName icon;
  final PillTone tone;
  final BK okKind;
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.okLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.icon,
    required this.tone,
    required this.okKind,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool busy = false;
  String error = '';

  Future<void> _confirm() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = e is ApiError ? e.message : tr('Something went wrong. Try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: widget.title,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.97),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: GlassTokens.border),
                  boxShadow: GlassTokens.shadow,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Start(IconTile(widget.icon, tone: widget.tone, size: 46)),
                  const SizedBox(height: 12),
                  Txt(widget.title, variant: TV.heading, style: const TextStyle(fontSize: 19)),
                  const SizedBox(height: 6),
                  Txt(widget.body),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Semantics(liveRegion: true, child: Txt(error, variant: TV.small, style: const TextStyle(color: AppColors.danger))),
                    ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Button(widget.cancelLabel, kind: BK.secondary, onPress: () => Navigator.of(context).pop(false))),
                    const SizedBox(width: 8),
                    Expanded(child: Button(widget.okLabel, kind: widget.okKind, loading: busy, onPress: _confirm)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
