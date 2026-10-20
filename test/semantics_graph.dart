import 'dart:ui' as ui;

// Проверяем сериализованные связи, затем передаём исходное обновление движку.
class SemanticsGraph {
  final nodes = <int, List<int>>{};
  final orphans = <int>[];
  int updates = 0;
  final labels = <int, Object?>{};
}

class RecordingSemanticsBuilder implements ui.SemanticsUpdateBuilder {
  RecordingSemanticsBuilder(this.graph, this.delegate);
  final SemanticsGraph graph;
  final ui.SemanticsUpdateBuilder delegate;
  final updated = <int>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateNode) {
      final args = invocation.namedArguments;
      final id = args[#id] as int;
      graph.labels[id] = args[#label];
      graph.nodes[id] = List<int>.of(
        args[#childrenInTraversalOrder] as Iterable<int>,
      );
      updated.add(id);
      return Function.apply(delegate.updateNode, [], args);
    }
    if (invocation.memberName == #updateCustomAction) {
      return Function.apply(
        delegate.updateCustomAction,
        [],
        invocation.namedArguments,
      );
    }
    return super.noSuchMethod(invocation);
  }

  @override
  ui.SemanticsUpdate build() {
    final reachable = <int>{};
    void visit(int id) {
      if (!reachable.add(id)) return;
      for (final child in graph.nodes[id] ?? <int>[]) {
        visit(child);
      }
    }

    visit(0);
    graph.orphans.addAll(updated.where((id) => !reachable.contains(id)));
    if (graph.orphans.isNotEmpty) {
      throw StateError(
        'Осиротевшие AX-узлы: ${graph.orphans.map((id) => '$id: ${graph.labels[id]}')}',
      );
    }
    graph.nodes.removeWhere((id, _) => !reachable.contains(id));
    graph.updates++;
    return delegate.build();
  }
}
