import 'package:flutter/material.dart';

class SearchableCryptoPicker extends StatelessWidget {
  const SearchableCryptoPicker({
    super.key,
    required this.currencies,
    required this.onSelected,
    this.selectedCurrency,
    this.label = 'Cryptocurrency',
    this.enabled = true,
  });

  final List<String> currencies;
  final String? selectedCurrency;
  final ValueChanged<String> onSelected;
  final String label;
  final bool enabled;

  Future<void> _showPicker(BuildContext context) async {
    if (!enabled || currencies.isEmpty) return;
    final searchController = TextEditingController();
    try {
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final height = (MediaQuery.sizeOf(sheetContext).height * 0.75)
              .clamp(280.0, 560.0)
              .toDouble();
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final query = searchController.text.trim().toLowerCase();
              final matches = currencies
                  .where((currency) => currency.toLowerCase().contains(query))
                  .toList(growable: false);
              return SafeArea(
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.viewInsetsOf(context).bottom + 12,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Choose $label',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        TextField(
                          controller: searchController,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search currencies',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      searchController.clear();
                                      setSheetState(() {});
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: matches.isEmpty
                              ? const Center(
                                  child: Text('No matching currencies'),
                                )
                              : ListView.builder(
                                  itemCount: matches.length,
                                  itemBuilder: (context, index) {
                                    final currency = matches[index];
                                    return ListTile(
                                      title: Text(currency.toUpperCase()),
                                      trailing: currency == selectedCurrency
                                          ? const Icon(Icons.check)
                                          : null,
                                      onTap: () =>
                                          Navigator.pop(context, currency),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      if (selected != null) onSelected(selected);
    } finally {
      searchController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _showPicker(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCurrency?.toUpperCase() ?? 'Choose a cryptocurrency',
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
