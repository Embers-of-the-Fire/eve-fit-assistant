library;

import 'package:eve_fit_assistant/native/port/api.dart';
import 'package:eve_fit_assistant/pages/fit/add_item_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/info/info_component.dart';
import 'package:eve_fit_assistant/pages/fit/slot.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/bool.dart';
import 'package:eve_fit_assistant/utils/itertools.dart';
import 'package:eve_fit_assistant/utils/optional.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'character.dart';

part 'config.dart';

part 'drone.dart';

part 'equipment.dart';

part 'fit.g.dart';

part 'info.dart';

void intoFitPage(BuildContext context, String fitID) {
  Navigator.of(context).push(MaterialPageRoute(builder: (context) => FitPage(fitID: fitID)));
}

@riverpod
class FitRecordNotifier extends _$FitRecordNotifier {
  @override
  FitRecordState build(String id) {
    final s = FitRecordState();

    GlobalStorage().ship.readFit(id).then((rec) {
      state = FitRecordState.init(rec);
    });

    return s;
  }

  Future<void> modify(FutureOr<FitRecord> Function(FitRecord) modifier) async {
    if (!state.initialized) {
      return;
    }

    final temp = FitRecordState.init(state.fit);
    temp.saved = false;
    state = temp;
    final fit = await modifier(state.fit);
    await fit.save();
    state = FitRecordState.init(fit);
  }
}

class FitRecordState {
  late FitRecord fit;
  late CalculateOutput output;
  bool saved = false;
  bool initialized = false;

  FitRecordState({this.saved = false});

  factory FitRecordState.init(FitRecord fit) {
    final s = FitRecordState();
    s.fit = fit;
    s.initialized = true;
    s.saved = true;
    s.output = GlobalStorage()
        .fitEngine
        .calculate(fit: fit.body, character: GlobalStorage().character.predefinedAll5);
    return s;
  }
}

class FitPage extends ConsumerWidget {
  final String fitID;

  const FitPage({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    if (!fit.initialized) {
      return const FitPagePlaceholder();
    }

    return FitPageContent(fitID: fitID);
  }
}

class FitPagePlaceholder extends StatelessWidget {
  const FitPagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('加载中...'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class FitPageError extends StatelessWidget {
  final Object error;

  const FitPageError({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('未知错误'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text(
              '未知错误',
              style: TextStyle(fontSize: 28, color: Colors.red),
            ),
            Text(error.toString()),
          ],
        ),
      ),
    );
  }
}

class FitPageContent extends ConsumerStatefulWidget {
  final String fitID;

  const FitPageContent({super.key, required this.fitID});

  @override
  ConsumerState<FitPageContent> createState() => _FitPageContentState();
}

class _FitPageContentState extends ConsumerState<FitPageContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(initialIndex: 1, length: 5, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fitRef = ref.read(fitRecordNotifierProvider(widget.fitID));
    final ship = GlobalStorage().static.ships[fitRef.fit.brief.shipID]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('[${ship.nameZH}] ${fitRef.fit.brief.name}'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: '角色'),
            Tab(text: '装备'),
            Tab(text: '属性'),
            Tab(text: '无人机'),
            Tab(text: '设置'),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(fitRef.saved ? Icons.download_done : Icons.downloading),
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CharacterTab(fitID: widget.fitID),
          EquipmentTab(fitID: widget.fitID, ship: ship),
          InfoTab(fitID: widget.fitID),
          DroneTab(fitID: widget.fitID),
          ConfigTab(
            fitID: widget.fitID,
            name: fitRef.fit.brief.name,
            description: fitRef.fit.brief.description,
          ),
          // Placeholder(),
        ],
      ),
    );
  }
}
