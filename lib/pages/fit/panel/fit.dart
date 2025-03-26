library;

import 'dart:math' show Random;

import 'package:eve_fit_assistant/assets/assets.dart';
import 'package:eve_fit_assistant/constant/eve/attribute.dart';
import 'package:eve_fit_assistant/constant/eve/market_groups.dart';
import 'package:eve_fit_assistant/native/algo/fighter.dart';
import 'package:eve_fit_assistant/native/glue/fit.dart';
import 'package:eve_fit_assistant/native/glue/native_slot.dart';
import 'package:eve_fit_assistant/native/port/api.dart';
import 'package:eve_fit_assistant/native/port/api/proxy.dart';
import 'package:eve_fit_assistant/pages/character/char_edit.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/add_item_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/panel/equipment_header.dart';
import 'package:eve_fit_assistant/pages/fit/panel/info/info_component.dart';
import 'package:eve_fit_assistant/pages/fit/panel/native_error.dart';
import 'package:eve_fit_assistant/pages/fit/panel/slot.dart';
import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:eve_fit_assistant/widgets/state_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'character.dart';

part 'config.dart';

part 'drone.dart';

part 'equipment.dart';

part 'fighter.dart';

part 'fit.g.dart';

part 'info.dart';

Future<void> intoFitPage(BuildContext context, String fitID) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (context) => FitPage(fitID: fitID)));
}

@riverpod
class FitRecordNotifier extends _$FitRecordNotifier {
  @override
  FitRecordState build(String id) {
    final s = FitRecordState();

    GlobalStorage().ship.readFit(id).then((rec) async {
      state = await FitRecordState.init(rec);
    });

    return s;
  }

  Future<void> modify(FutureOr<FitRecord> Function(FitRecord) modifier) async {
    if (!state.initialized) {
      return;
    }

    final temp = await FitRecordState.init(state.fit);
    temp.saved = false;
    state = temp;
    final fit = await modifier(state.fit);
    await fit.save();
    state = await FitRecordState.init(fit);
  }

  Future<void> setCharacter(String newCharacterID) async {
    if (!state.initialized) {
      return;
    }

    final temp = await FitRecordState.init(state.fit);
    temp.saved = false;
    state = temp;
    final fit = state.fit;
    fit.body.characterID = newCharacterID;
    await fit.save();
    state = await FitRecordState.init(fit);
  }

  Future<void> refresh() async {
    state = await FitRecordState.init(state.fit);
  }
}

class FitRecordState {
  late FitRecord fit;
  late Character character;
  late CalculateOutput output;
  bool saved = false;
  bool initialized = false;

  FitRecordState({this.saved = false});

  static Future<FitRecordState> init(FitRecord fit) async {
    final s = FitRecordState();
    s.fit = fit;
    s.character = await GlobalStorage().character.get(fit.body.characterID);
    s.output = GlobalStorage()
        .fitEngine
    // .calculate(fit: fit.body, character: GlobalStorage().character.predefinedAll5);
        .calculate(
      fit: fit.body,
      character: s.character,
    );
    s.initialized = true;
    s.saved = true;
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
  Widget build(BuildContext context) =>
      Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
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

    if (ship.hasFighter) {
      return _buildFighter(context);
    } else {
      return _buildDrone(context);
    }
  }

  Widget _buildDrone(BuildContext context) {
    final fitRef = ref.read(fitRecordNotifierProvider(widget.fitID));
    final ship = GlobalStorage().static.ships[fitRef.fit.brief.shipID]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('[${ship.nameZH}] ${fitRef.fit.brief.name}'),
        bottom: TabBar(
          controller: _tabController,
          labelPadding: EdgeInsets.zero,
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
      body: SafeArea(bottom: true, child: TabBarView(
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
        ],
      )),
    );
  }

  Widget _buildFighter(BuildContext context) {
    final fitRef = ref.read(fitRecordNotifierProvider(widget.fitID));
    final ship = GlobalStorage().static.ships[fitRef.fit.brief.shipID]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('[${ship.nameZH}] ${fitRef.fit.brief.name}'),
        bottom: TabBar(
          controller: _tabController,
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(text: '角色'),
            Tab(text: '装备'),
            Tab(text: '属性'),
            Tab(text: '舰载机'),
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
          FighterTab(fitID: widget.fitID),
          ConfigTab(
            fitID: widget.fitID,
            name: fitRef.fit.brief.name,
            description: fitRef.fit.brief.description,
          ),
        ],
      ),
    );
  }
}
