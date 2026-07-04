import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../core/finance_models.dart';

String walletTypeLabel(WalletType type) => switch (type) {
  WalletType.cash => 'Tiền mặt',
  WalletType.bank => 'Ngân hàng',
  WalletType.eWallet => 'Ví điện tử',
  WalletType.creditCard => 'Thẻ tín dụng',
};

String localizedWalletTypeLabel(BuildContext context, WalletType type) =>
    switch (type) {
      WalletType.cash => context.l10n.t('walletCash'),
      WalletType.bank => context.l10n.t('walletBank'),
      WalletType.eWallet => context.l10n.t('walletEWallet'),
      WalletType.creditCard => context.l10n.t('walletCreditCard'),
    };

String compactVndLabel(num value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000000) {
    return '$sign${_compactNumber(amount / 1000000000)}B';
  }
  if (amount >= 1000000) {
    return '$sign${_compactNumber(amount / 1000000)}M';
  }
  if (amount >= 1000) {
    return '$sign${_compactNumber(amount / 1000)}K';
  }
  return '$sign${amount.round()}';
}

String _compactNumber(num value) {
  final text = value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return text.replaceFirst(RegExp(r'\.0$'), '');
}
