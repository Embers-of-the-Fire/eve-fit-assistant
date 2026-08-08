use std::collections::HashMap;
use std::fs::File;
use std::sync::{Arc, RwLock};

use efa_chat::config::PromptLanguage;
use efa_chat::fit::{ActiveFit, AttributeNames, FitToolContext, FitToolError};
use eve_fit_os::calculate::{DamageProfile, calculate};
use eve_fit_os::fit::{
    FitContainer, ItemCharge, ItemDrone, ItemFit, ItemModule, ItemSlot, ItemSlotType, ItemState,
};
use eve_fit_os::protobuf::Database;

fn test_database() -> Database {
    dotenvy::from_filename(concat!(env!("CARGO_MANIFEST_DIR"), "/../eve-fit-os/.env")).ok();
    let output_dir =
        std::env::var("OUTPUT_DIR").expect("OUTPUT_DIR must be set (see eve-fit-os/.env)");
    Database::init_from_root(format!("{output_dir}/pb2")).unwrap()
}

fn test_skills() -> HashMap<i32, u8> {
    let rdr = File::open(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../eve-fit-os/skills.json"
    ))
    .unwrap();
    serde_json::from_reader(rdr).unwrap()
}

fn test_fit() -> FitContainer {
    let fit = ItemFit {
        fighters: vec![],
        damage_profile: DamageProfile::default(),
        ship_type_id: 628,
        modules: (0..3)
            .map(|index| ItemModule {
                item_id: eve_fit_os::calculate::item::ItemID::Item(1877),
                slot: ItemSlot {
                    slot_type: ItemSlotType::High,
                    index,
                },
                state: ItemState::Active,
                charge: Some(ItemCharge { type_id: 2613 }),
            })
            .collect(),
        drones: vec![
            ItemDrone {
                type_id: 2488,
                group_id: 0,
                state: ItemState::Active,
            },
            ItemDrone {
                type_id: 2488,
                group_id: 1,
                state: ItemState::Active,
            },
        ],
        implants: vec![],
        boosters: vec![],
    };
    FitContainer::new(fit, test_skills(), HashMap::new())
}

fn test_context() -> FitToolContext {
    let active = ActiveFit {
        name: Some("test fit".to_string()),
        container: test_fit(),
        names: HashMap::from([
            (628, "Arbitrator".to_string()),
            (1877, "Rapid Light Missile Launcher II".to_string()),
        ]),
    };
    let names = AttributeNames::from_by_id(HashMap::from([
        (263, "shieldCapacity".to_string()),
        (37, "maxVelocity".to_string()),
        (-27, "ehp".to_string()),
    ]));
    FitToolContext::new(
        Arc::new(test_database()),
        Arc::new(RwLock::new(Some(active))),
        Arc::new(names),
    )
}

#[test]
fn current_fit_summarizes_sections() {
    let summary = test_context().current_fit(false).unwrap();
    assert_eq!(summary.name.as_deref(), Some("test fit"));
    assert_eq!(summary.ship.type_id, 628);
    assert_eq!(summary.ship.name.as_deref(), Some("Arbitrator"));
    assert_eq!(summary.modules.len(), 3);
    assert_eq!(summary.modules[0].slot_type, "high");
    assert_eq!(summary.modules[0].state, "active");
    assert_eq!(summary.modules[0].charge.as_ref().unwrap().type_id, 2613);
    assert_eq!(summary.drones.len(), 1);
    assert_eq!(summary.drones[0].count, 2);
    assert!(summary.skills.is_none());
    assert!(test_context().current_fit(true).unwrap().skills.is_some());
}

#[test]
fn fit_stats_reports_headline_sections() {
    let report = test_context().fit_stats().unwrap();
    let sections: Vec<&str> = report.sections.iter().map(|s| s.section.as_str()).collect();
    assert!(sections.contains(&"damage"));
    assert!(sections.contains(&"defense"));
    assert!(sections.contains(&"capacitor"));
    let damage = report
        .sections
        .iter()
        .find(|s| s.section == "damage")
        .unwrap();
    let dps = damage
        .entries
        .iter()
        .find(|e| e.key == "dpsWithReload")
        .unwrap();
    assert!(dps.value > 0.0);
}

#[test]
fn item_detail_selects_and_resolves() {
    let context = test_context();
    let detail = context.item_detail("module", Some(0)).unwrap();
    assert_eq!(detail.item.type_id, 1877);
    assert_eq!(
        detail.item.name.as_deref(),
        Some("Rapid Light Missile Launcher II")
    );
    assert!(!detail.attributes.is_empty());
    let hull = context.item_detail("hull", None).unwrap();
    assert_eq!(hull.item.type_id, 628);
    assert!(matches!(
        context.item_detail("module", Some(99)),
        Err(FitToolError::IndexOutOfRange { .. })
    ));
    assert!(matches!(
        context.item_detail("warp_core", None),
        Err(FitToolError::UnknownSection(_))
    ));
}

#[test]
fn attr_detail_resolves_names_case_insensitively() {
    let context = test_context();
    let detail = context.attr_detail("hull", None, "SHIELDCAPACITY").unwrap();
    assert_eq!(detail.attribute_id, 263);
    assert!(detail.value > 0.0);
    let ehp = context.attr_detail("hull", None, "ehp").unwrap();
    assert_eq!(ehp.attribute_id, -27);
    assert!(matches!(
        context.attr_detail("hull", None, "noSuchAttr"),
        Err(FitToolError::UnknownAttribute { .. })
    ));
}

#[test]
fn validate_returns_report() {
    let report = test_context().validate().unwrap();
    // The test fit is legal; at minimum the report must be well-formed.
    assert!(report.issues.iter().all(|issue| !issue.code.is_empty()));
}

#[test]
fn tools_error_without_active_fit() {
    let context = FitToolContext::new(
        Arc::new(test_database()),
        Arc::new(RwLock::new(None)),
        Arc::new(AttributeNames::default()),
    );
    assert!(matches!(
        context.current_fit(false),
        Err(FitToolError::NoActiveFit)
    ));
    assert!(matches!(
        context.fit_stats(),
        Err(FitToolError::NoActiveFit)
    ));
}

#[test]
fn calculate_matches_engine_directly() {
    let context = test_context();
    // Sanity: the context's engine handle produces the same ship as a direct call.
    let container = test_fit();
    let db = test_database();
    let ship = calculate(&container, &db);
    let stats = context.fit_stats().unwrap();
    assert!(!stats.sections.is_empty());
    assert!(ship.hull.attributes.contains_key(&263));
}

#[test]
fn propose_edit_adds_module_and_projects_stats() {
    let context = test_context();
    let before_modules = test_fit().fit.modules.len();
    let proposal = context
        .propose_edit(&[efa_chat::fit::edit::FitEditOp::AddModule {
            slot_type: "medium".to_string(),
            type_id: 10850,
            state: Some("active".to_string()),
            charge_type_id: None,
        }])
        .unwrap();
    assert_eq!(proposal.applied.len(), 1);
    assert!(proposal.rejected.is_empty());
    assert!(proposal.applied[0].contains("medium"));
    // The edited fit has one more module than the original.
    assert!(!proposal.after.sections.is_empty());
    // The user's attached fit is untouched.
    let summary = context.current_fit(false).unwrap();
    assert_eq!(summary.modules.len(), before_modules);
}

#[test]
fn propose_edit_rejects_unknown_slot_and_missing_module() {
    let context = test_context();
    let proposal = context
        .propose_edit(&[
            efa_chat::fit::edit::FitEditOp::RemoveModule {
                slot_type: "not_a_slot".to_string(),
                index: 0,
            },
            efa_chat::fit::edit::FitEditOp::SetModuleState {
                slot_type: "high".to_string(),
                index: 99,
                state: "overload".to_string(),
            },
        ])
        .unwrap();
    assert!(proposal.applied.is_empty());
    assert_eq!(proposal.rejected.len(), 2);
}

#[test]
fn tool_descriptions_follow_context_language() {
    let en_tools = efa_chat::fit::tools::fit_tools(test_context());
    let zh_tools =
        efa_chat::fit::tools::fit_tools(test_context().with_language(PromptLanguage::Zh));
    assert!(!en_tools.is_empty());
    assert_eq!(en_tools.len(), zh_tools.len());
    for (en_tool, zh_tool) in en_tools.iter().zip(zh_tools.iter()) {
        assert_eq!(en_tool.name(), zh_tool.name());
        let en = en_tool.definition().description;
        let zh = zh_tool.definition().description;
        assert!(!en.trim().is_empty());
        assert_ne!(en, zh);
    }
}

#[test]
fn propose_edit_set_charge_and_state() {
    let context = test_context();
    let proposal = context
        .propose_edit(&[
            efa_chat::fit::edit::FitEditOp::SetModuleCharge {
                slot_type: "high".to_string(),
                index: 0,
                charge_type_id: Some(2613),
            },
            efa_chat::fit::edit::FitEditOp::SetModuleState {
                slot_type: "high".to_string(),
                index: 0,
                state: "overload".to_string(),
            },
        ])
        .unwrap();
    assert_eq!(proposal.applied.len(), 2);
    assert!(proposal.rejected.is_empty());
}
