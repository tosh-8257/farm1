import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/business/ops/ops_ui.dart';
import '/pages/investments/investment_pages.dart';

import 'investment_marketplace_model.dart';
export 'investment_marketplace_model.dart';

/// Existing personal marketplace page, extended (V2 Phase 4) into the
/// multi-sector marketplace. No returns are shown or promised.
class InvestmentMarketplaceWidget extends StatefulWidget {
  const InvestmentMarketplaceWidget({super.key});

  static String routeName = 'InvestmentMarketplace';
  static String routePath = '/investmentMarketplace';

  @override
  State<InvestmentMarketplaceWidget> createState() =>
      _InvestmentMarketplaceWidgetState();
}

class _InvestmentMarketplaceWidgetState
    extends State<InvestmentMarketplaceWidget> {
  late InvestmentMarketplaceModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InvestmentMarketplaceModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed('Dashboard');
      },
      child: BizScaffold(
        title: 'Investment marketplace',
        actions: [
          IconButton(
            tooltip: 'My investments',
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: () => pushPage(context, const PortfolioPage()),
          ),
        ],
        body: const MarketplaceBody(),
      ),
    );
  }
}
