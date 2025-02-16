// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import 'api/data.dart';
import 'api/error.dart';
import 'api/proxy.dart';
import 'api/schema.dart';
import 'frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';


            

            CalculateOutput  calculate({required EveDatabase db , required Fit fit }) => RustLib.instance.api.crateApiCalculate(db: db, fit: fit);

            class CalculateOutput  {
                final ShipProxy ship;
final List<SlotInfo> errors;

                const CalculateOutput({required this.ship ,required this.errors ,});

                
                

                
        @override
        int get hashCode => ship.hashCode^errors.hashCode;
        

                
        @override
        bool operator ==(Object other) =>
            identical(this, other) ||
            other is CalculateOutput &&
                runtimeType == other.runtimeType
                && ship == other.ship&& errors == other.errors;
        
            }
            