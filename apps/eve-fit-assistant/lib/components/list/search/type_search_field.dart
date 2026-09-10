import "dart:async";

import "package:eve_fit_assistant/components/list/search/type_searcher.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

/// Debounce delay applied to picker search input.
const Duration _debounceDelay = Duration(milliseconds: 300);

/// A debounced search field resolving matching EVE type ids through an
/// [EveTypeSearcher].
///
/// Reports `null` through [onResults] while the field is empty (browse mode)
/// and the matching type ids once a query settles. Rendering and selecting
/// results is left to the caller, so any item picker can embed this field.
class EveTypeSearchField extends StatefulWidget {
  const EveTypeSearchField({required this.searcher, required this.onResults, super.key});

  final EveTypeSearcher searcher;

  /// Called with matching type ids, or `null` when the search is inactive.
  final void Function(List<int>? typeIds) onResults;

  @override
  State<EveTypeSearchField> createState() => _EveTypeSearchFieldState();
}

class _EveTypeSearchFieldState extends State<EveTypeSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      // Back to browse mode; invalidate any in-flight search.
      _generation++;
      widget.onResults(null);
      return;
    }
    _debounce = Timer(_debounceDelay, () => unawaited(_runSearch(value)));
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_generation;
    final hits = await widget.searcher(query);
    // Drop results overtaken by a newer query or a cleared field.
    if (!mounted || generation != _generation) return;
    widget.onResults(hits);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: _onQueryChanged,
    decoration: InputDecoration(
      isDense: true,
      hintText: context.l10n.typeSearchHint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _controller.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: context.l10n.typeSearchClear,
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  _onQueryChanged("");
                },
              ),
      ),
      border: const OutlineInputBorder(),
    ),
  );
}
