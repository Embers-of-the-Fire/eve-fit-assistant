library;

import 'package:animated_tree_view/helpers/collection_utils.dart';
import 'package:eve_fit_assistant/assets/icon.dart';
import 'package:eve_fit_assistant/constant/eve/attribute.dart';
import 'package:eve_fit_assistant/native/algo/capacitor.dart';
import 'package:eve_fit_assistant/native/port/api/proxy.dart';
import 'package:eve_fit_assistant/native/port/api/schema.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/damage_profile_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/pages/market/market_list.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/market/market.dart';
import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:eve_fit_assistant/widgets/resonance_box.dart';
import 'package:eve_fit_assistant/widgets/resource_compare.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'capacitor.dart';
part 'extra.dart';
part 'hp.dart';
part 'info_component.g.dart';
part 'market_price.dart';
part 'resource.dart';
part 'ship.dart';
part 'weapon.dart';
