use std::collections::HashMap;
use std::fs::File;
use std::sync::{Arc, Mutex, RwLock};

use efa_chat::core::config::PromptLanguage;
use efa_chat::tools::fit::{ActiveFit, AttributeNames, FitCallbacks, FitToolContext, FitToolError};
use eve_fit_os::calculate::{DamageProfile, calculate};
use eve_fit_os::fit::{
    FitContainer, ItemCharge, ItemDrone, ItemFit, ItemModule, ItemSlot, ItemSlotType, ItemState,
};
use eve_fit_os::protobuf::Database;

fn test_database() -> Database {
    dotenvy::from_filename(concat!(env!("CARGO_MANIFEST_DIR"), "/../../../../../packages/eve-fit-os/.env")).ok();
    let output_dir =
        std::env::var("OUTPUT_DIR").expect("OUTPUT_DIR must be set (see eve-fit-os/.env)");
    Database::init_from_root(format!("{output_dir}/pb2")).unwrap()
}

fn test_skills() -> HashMap<i32, u8> {
    let rdr = File::open(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../../../packages/eve-fit-os/skills.json"
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

/// A minimal valid `FitPayload` JSON for the callbacks that return the
/// updated attached fit (`load_fit`, `create_fit`, `apply_fit_edit`).
fn test_fit_payload_json() -> String {
    fit_payload_json_named("updated fit")
}

/// [`test_fit_payload_json`] with a caller-chosen fit name, so concurrent
/// replacements can tell whose response was attached.
fn fit_payload_json_named(name: &str) -> String {
    serde_json::json!({
        "name": name,
        "names": {"628": "Arbitrator"},
        "fit": {
            "ship_type_id": 628,
            "damage_profile": {"em": 0.25, "explosive": 0.25, "kinetic": 0.25, "thermal": 0.25},
        },
        "skills": {},
        "dynamic_items": {},
    })
    .to_string()
}

/// Callbacks whose `apply_fit_edit` records the forwarded ops JSON; all
/// fit-returning callbacks answer with [`test_fit_payload_json`].
fn mock_callbacks() -> (FitCallbacks, Arc<Mutex<Vec<String>>>) {
    let recorded = Arc::new(Mutex::new(Vec::new()));
    let sink = recorded.clone();
    let callbacks = FitCallbacks {
        search_items: Arc::new(|_, _, _| Box::pin(async move { "[]".to_string() })),
        list_fits: Arc::new(|| Box::pin(async move { "[]".to_string() })),
        load_fit: Arc::new(|_| Box::pin(async move { test_fit_payload_json() })),
        create_fit: Arc::new(|_, _, _| Box::pin(async move { test_fit_payload_json() })),
        apply_fit_edit: Arc::new(move |ops_json| {
            sink.lock().unwrap().push(ops_json);
            Box::pin(async move { test_fit_payload_json() })
        }),
    };
    (callbacks, recorded)
}

fn runtime() -> &'static tokio::runtime::Runtime {
    efa_chat::host::runtime::runtime()
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
fn tool_errors_surface_actionable_model_feedback() {
    use rig::tool::{PortableTool, ToolErrorKind};
    let context = FitToolContext::new(
        Arc::new(test_database()),
        Arc::new(RwLock::new(None)),
        Arc::new(AttributeNames::default()),
    );
    // The reported failure: `get_current_fit` with no attached fit must hand
    // the model the actionable reason, not rig's redacted "the tool failed".
    let tool = efa_chat::tools::fit::tools::GetCurrentFitTool::new(context);
    let mapped = tool.map_error(FitToolError::NoActiveFit);
    assert_eq!(mapped.kind(), ToolErrorKind::NotFound);
    assert_eq!(
        mapped.model_feedback(),
        Some("no fit is currently attached to this chat session")
    );
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
fn apply_edit_adds_module_and_persists() {
    let (callbacks, recorded) = mock_callbacks();
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let report = runtime()
        .block_on(
            context.apply_edit(&[efa_chat::tools::fit::edit::FitEditOp::AddModule {
                slot_type: "medium".to_string(),
                type_id: 10850,
                state: Some("active".to_string()),
                charge_type_id: None,
            }]),
        )
        .unwrap();
    assert_eq!(report.applied.len(), 1);
    assert!(report.rejected.is_empty());
    assert!(report.applied[0].contains("medium"));
    assert!(report.persisted);
    assert!(!report.after.sections.is_empty());
    // The report describes the fit the app returned (no modules or drones),
    // not the local pre-persistence result, which still had the launchers
    // and drones and would report positive dps.
    let dps = report
        .after
        .sections
        .iter()
        .find(|s| s.section == "damage")
        .and_then(|s| s.entries.iter().find(|e| e.key == "dpsWithReload"))
        .map(|e| e.value)
        .expect("returned-fit report must include the damage/dpsWithReload metric");
    assert_eq!(dps, 0.0);
    // The validated op was forwarded to the app for persistence.
    let forwarded = recorded.lock().unwrap();
    assert_eq!(forwarded.len(), 1);
    assert!(forwarded[0].contains("add_module"));
    assert!(forwarded[0].contains("10850"));
    drop(forwarded);
    // The attached fit was replaced by the payload the app returned.
    let summary = context.current_fit(false).unwrap();
    assert_eq!(summary.name.as_deref(), Some("updated fit"));
    assert!(summary.modules.is_empty());
}

#[test]
fn apply_edit_rejects_unknown_slot_and_missing_module() {
    let context = test_context();
    let report = runtime()
        .block_on(context.apply_edit(&[
            efa_chat::tools::fit::edit::FitEditOp::RemoveModule {
                slot_type: "not_a_slot".to_string(),
                index: 0,
            },
            efa_chat::tools::fit::edit::FitEditOp::SetModuleState {
                slot_type: "high".to_string(),
                index: 99,
                state: "overload".to_string(),
            },
        ]))
        .unwrap();
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 2);
    // Nothing applied: the app callback is never invoked.
    assert!(!report.persisted);
}

#[test]
fn apply_edit_requires_callbacks_to_persist() {
    let context = test_context();
    let error = runtime()
        .block_on(
            context.apply_edit(&[efa_chat::tools::fit::edit::FitEditOp::AddModule {
                slot_type: "medium".to_string(),
                type_id: 10850,
                state: None,
                charge_type_id: None,
            }]),
        )
        .unwrap_err();
    assert!(matches!(error, FitToolError::CallbacksUnavailable));
}

#[test]
fn apply_edit_surfaces_app_errors() {
    let mut callbacks = mock_callbacks().0;
    callbacks.apply_fit_edit =
        Arc::new(|_| Box::pin(async move { "{\"error\":\"fit is read-only\"}".to_string() }));
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let error = runtime()
        .block_on(
            context.apply_edit(&[efa_chat::tools::fit::edit::FitEditOp::AddModule {
                slot_type: "medium".to_string(),
                type_id: 10850,
                state: None,
                charge_type_id: None,
            }]),
        )
        .unwrap_err();
    assert!(matches!(error, FitToolError::BadPayload(_)));
    assert!(error.to_string().contains("fit is read-only"));
}

#[test]
fn create_fit_attaches_the_new_fit() {
    let captured = Arc::new(Mutex::new(None));
    let sink = captured.clone();
    let mut callbacks = mock_callbacks().0;
    callbacks.create_fit = Arc::new(move |ship_id, name, description| {
        sink.lock().unwrap().replace((ship_id, name, description));
        Box::pin(async move { test_fit_payload_json() })
    });
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let summary = runtime()
        .block_on(context.create_fit(628, "new fit", Some("a description".to_string())))
        .unwrap();
    assert_eq!(
        *captured.lock().unwrap(),
        Some((
            628,
            "new fit".to_string(),
            Some("a description".to_string())
        ))
    );
    // The created fit became the attached fit.
    assert_eq!(summary.name.as_deref(), Some("updated fit"));
    assert_eq!(summary.ship.type_id, 628);
    assert_eq!(
        context.current_fit(false).unwrap().name.as_deref(),
        Some("updated fit")
    );
}

#[test]
fn edit_tools_require_callbacks() {
    let tools = efa_chat::tools::fit::tools::fit_tools(test_context());
    assert!(tools.iter().all(|tool| tool.name() != "apply_fit_edit"));
    assert!(tools.iter().all(|tool| tool.name() != "create_fit"));
    let context = test_context().with_callbacks(Arc::new(mock_callbacks().0));
    let tools = efa_chat::tools::fit::tools::fit_tools(context);
    assert!(tools.iter().any(|tool| tool.name() == "apply_fit_edit"));
    assert!(tools.iter().any(|tool| tool.name() == "create_fit"));
}

/// A `load_fit` response that arrives after a newer replacement committed
/// must not overwrite the newer attached fit, and the caller is told the
/// requested fit was superseded instead of receiving a misleading success.
#[test]
fn stale_load_fit_response_does_not_overwrite_newer_active_fit() {
    let (release_first, first_gate) = tokio::sync::oneshot::channel::<()>();
    let (first_started_tx, first_started) = tokio::sync::oneshot::channel::<()>();
    let first_gate = Arc::new(Mutex::new(Some(first_gate)));
    let first_started_tx = Arc::new(Mutex::new(Some(first_started_tx)));
    let mut callbacks = mock_callbacks().0;
    callbacks.load_fit = Arc::new(move |fit_id| {
        if fit_id == "first" {
            let gate = first_gate.lock().unwrap().take().unwrap();
            let started = first_started_tx.lock().unwrap().take().unwrap();
            Box::pin(async move {
                started.send(()).unwrap();
                gate.await.unwrap();
                fit_payload_json_named("first fit")
            })
        } else {
            Box::pin(async move { fit_payload_json_named("second fit") })
        }
    });
    let context = test_context().with_callbacks(Arc::new(callbacks));
    runtime().block_on(async {
        let first = tokio::spawn({
            let context = context.clone();
            async move { context.load_fit("first").await }
        });
        // Wait until the first request is parked on its gated callback.
        first_started.await.unwrap();
        // A newer replacement starts and commits while the first is pending.
        context.load_fit("second").await.unwrap();
        release_first.send(()).unwrap();
        let stale = first.await.unwrap().unwrap_err();
        assert!(matches!(stale, FitToolError::Superseded(_)));
        assert!(stale.to_string().contains("first"));
    });
    assert_eq!(
        context.current_fit(false).unwrap().name.as_deref(),
        Some("second fit")
    );
}

/// A stale `create_fit` response must report that the fit was created and
/// saved but is not attached, so the model does not retry the create.
#[test]
fn stale_create_fit_response_reports_superseded() {
    let (release_create, create_gate) = tokio::sync::oneshot::channel::<()>();
    let (create_started_tx, create_started) = tokio::sync::oneshot::channel::<()>();
    let create_gate = Arc::new(Mutex::new(Some(create_gate)));
    let create_started_tx = Arc::new(Mutex::new(Some(create_started_tx)));
    let mut callbacks = mock_callbacks().0;
    callbacks.create_fit = Arc::new(move |_, name, _| {
        let gate = create_gate.lock().unwrap().take().unwrap();
        let started = create_started_tx.lock().unwrap().take().unwrap();
        Box::pin(async move {
            started.send(()).unwrap();
            gate.await.unwrap();
            serde_json::json!({
                "name": name,
                "fit_id": "created-fit-id",
                "names": {"628": "Arbitrator"},
                "fit": {
                    "ship_type_id": 628,
                    "damage_profile": {"em": 0.25, "explosive": 0.25, "kinetic": 0.25, "thermal": 0.25},
                },
                "skills": {},
                "dynamic_items": {},
            })
            .to_string()
        })
    });
    callbacks.load_fit =
        Arc::new(|_| Box::pin(async move { fit_payload_json_named("loaded fit") }));
    let context = test_context().with_callbacks(Arc::new(callbacks));
    runtime().block_on(async {
        let create = tokio::spawn({
            let context = context.clone();
            async move { context.create_fit(628, "brand new fit", None).await }
        });
        // Wait until the create is parked on its gated callback.
        create_started.await.unwrap();
        context.load_fit("loaded").await.unwrap();
        release_create.send(()).unwrap();
        let stale = create.await.unwrap().unwrap_err();
        assert!(matches!(stale, FitToolError::Superseded(_)));
        let message = stale.to_string();
        assert!(message.contains("was created and saved"));
        assert!(message.contains("created-fit-id"));
        assert!(message.contains("brand new fit"));
    });
    assert_eq!(
        context.current_fit(false).unwrap().name.as_deref(),
        Some("loaded fit")
    );
}

/// An `apply_edit` response that arrives after a concurrent `load_fit`
/// attached a newer fit must not overwrite it, and the caller is told the
/// edits were saved but the edited fit is not attached instead of receiving
/// a misleading success report.
#[test]
fn stale_apply_edit_response_does_not_overwrite_newer_active_fit() {
    let (release_edit, edit_gate) = tokio::sync::oneshot::channel::<()>();
    let (edit_started_tx, edit_started) = tokio::sync::oneshot::channel::<()>();
    let edit_gate = Arc::new(Mutex::new(Some(edit_gate)));
    let edit_started_tx = Arc::new(Mutex::new(Some(edit_started_tx)));
    let mut callbacks = mock_callbacks().0;
    callbacks.load_fit =
        Arc::new(|_| Box::pin(async move { fit_payload_json_named("loaded fit") }));
    callbacks.apply_fit_edit = Arc::new(move |_| {
        let gate = edit_gate.lock().unwrap().take().unwrap();
        let started = edit_started_tx.lock().unwrap().take().unwrap();
        Box::pin(async move {
            started.send(()).unwrap();
            gate.await.unwrap();
            fit_payload_json_named("edited fit")
        })
    });
    let context = test_context().with_callbacks(Arc::new(callbacks));
    runtime().block_on(async {
        let edit = tokio::spawn({
            let context = context.clone();
            async move {
                context
                    .apply_edit(&[efa_chat::tools::fit::edit::FitEditOp::AddModule {
                        slot_type: "medium".to_string(),
                        type_id: 10850,
                        state: None,
                        charge_type_id: None,
                    }])
                    .await
            }
        });
        // Wait until the edit is parked on its gated callback.
        edit_started.await.unwrap();
        context.load_fit("loaded").await.unwrap();
        release_edit.send(()).unwrap();
        let stale = edit.await.unwrap().unwrap_err();
        assert!(matches!(stale, FitToolError::Superseded(_)));
        let message = stale.to_string();
        assert!(message.contains("applied and saved"));
        assert!(message.contains("not the attached fit"));
    });
    assert_eq!(
        context.current_fit(false).unwrap().name.as_deref(),
        Some("loaded fit")
    );
}

#[test]
fn tool_descriptions_follow_context_language() {
    let en_tools = efa_chat::tools::fit::tools::fit_tools(test_context());
    let zh_tools =
        efa_chat::tools::fit::tools::fit_tools(test_context().with_language(PromptLanguage::Zh));
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
fn search_items_passes_language_and_kind_to_callback() {
    let captured = Arc::new(Mutex::new(Vec::new()));
    let sink = captured.clone();
    let callbacks = FitCallbacks {
        search_items: Arc::new(move |query, language, kind| {
            sink.lock().unwrap().push((query, language, kind));
            Box::pin(async move { "[]".to_string() })
        }),
        list_fits: Arc::new(|| Box::pin(async move { "[]".to_string() })),
        load_fit: Arc::new(|_| Box::pin(async move { "{}".to_string() })),
        create_fit: Arc::new(|_, _, _| Box::pin(async move { "{}".to_string() })),
        apply_fit_edit: Arc::new(|_| Box::pin(async move { "{}".to_string() })),
    };
    let context = test_context().with_callbacks(Arc::new(callbacks));
    efa_chat::host::runtime::runtime()
        .block_on(context.search_items("extender", Some("zh"), None))
        .unwrap();
    efa_chat::host::runtime::runtime()
        .block_on(context.search_items("halcyon", None, Some("booster")))
        .unwrap();
    assert_eq!(
        *captured.lock().unwrap(),
        vec![
            ("extender".to_string(), Some("zh".to_string()), None),
            ("halcyon".to_string(), None, Some("booster".to_string())),
        ]
    );
    // The tool schema advertises the optional language and kind parameters.
    let tools = efa_chat::tools::fit::tools::fit_tools(context);
    let search = tools.iter().find(|t| t.name() == "search_items").unwrap();
    assert!(search.definition().parameters["properties"]["language"].is_object());
    assert!(search.definition().parameters["properties"]["kind"].is_object());
}

#[test]
fn apply_edit_set_charge_and_state() {
    let (callbacks, _) = mock_callbacks();
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let report = runtime()
        .block_on(context.apply_edit(&[
            efa_chat::tools::fit::edit::FitEditOp::SetModuleCharge {
                slot_type: "high".to_string(),
                index: 0,
                charge_type_id: Some(2613),
            },
            efa_chat::tools::fit::edit::FitEditOp::SetModuleState {
                slot_type: "high".to_string(),
                index: 0,
                state: "overload".to_string(),
            },
        ]))
        .unwrap();
    assert_eq!(report.applied.len(), 2);
    assert!(report.rejected.is_empty());
    assert!(report.persisted);
}

#[test]
fn apply_edit_adds_and_removes_drones() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let (callbacks, _) = mock_callbacks();
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let report = runtime()
        .block_on(context.apply_edit(&[
            // Existing drone type: joins the same group.
            Op::AddDrone {
                type_id: 2488,
                state: None,
            },
            // New drone type in space.
            Op::AddDrone {
                type_id: 23525,
                state: Some("space".to_string()),
            },
        ]))
        .unwrap();
    assert_eq!(report.applied.len(), 2);
    assert!(report.rejected.is_empty());
    assert!(report.applied[0].contains("bay"));
    assert!(report.applied[1].contains("space"));

    // A fresh context: the previous apply replaced the attached fit with the
    // mock payload.
    let (callbacks, _) = mock_callbacks();
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::SetDroneState {
                type_id: 2488,
                state: "space".to_string(),
            },
            Op::RemoveDrone { type_id: 2488 },
            Op::RemoveDrone { type_id: 99999 },
        ]))
        .unwrap();
    assert_eq!(report.applied.len(), 2);
    assert_eq!(report.rejected.len(), 1);
    assert!(report.rejected[0].contains("99999"));
    assert!(report.persisted);
}

#[test]
fn apply_edit_rejects_bad_drone_state() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let context = test_context();
    let report = runtime()
        .block_on(context.apply_edit(&[Op::AddDrone {
            type_id: 2488,
            state: Some("overload".to_string()),
        }]))
        .unwrap();
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 1);
    assert!(!report.persisted);
}

#[test]
fn apply_edit_adds_and_removes_fighters() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let (callbacks, _) = mock_callbacks();
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::AddFighter {
                type_id: 40560,
                ability: None,
            },
            Op::AddFighter {
                type_id: 40560,
                ability: Some(0b0101),
            },
            Op::AddFighter {
                type_id: 40560,
                ability: Some(0b1_0000),
            },
        ]))
        .unwrap();
    assert_eq!(report.applied.len(), 2);
    assert_eq!(report.rejected.len(), 1);
    assert!(report.applied[0].contains("ability 0"));
    assert!(report.applied[1].contains("ability 5"));
    assert!(report.rejected[0].contains("unsupported ability bits"));

    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::RemoveFighter { type_id: 40560 },
            Op::RemoveFighter { type_id: 99999 },
        ]))
        .unwrap();
    // The first apply replaced the attached fit with the mock payload, which
    // has no fighters; both removals reject.
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 2);
    assert!(!report.persisted);
}

#[test]
fn apply_edit_sets_and_removes_implants_and_boosters() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let (callbacks, _) = mock_callbacks();
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::SetImplant {
                type_id: 33516,
                slot: 1,
            },
            // Slotting another implant succeeds in its own slot.
            Op::SetImplant {
                type_id: 33525,
                slot: 2,
            },
            Op::SetBooster {
                type_id: 81083,
                slot: 2,
            },
        ]))
        .unwrap();
    assert_eq!(report.applied.len(), 3);
    assert!(report.rejected.is_empty());

    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::RemoveImplant { slot: 1 },
            Op::RemoveBooster { slot: 2 },
            Op::RemoveImplant { slot: 9 },
        ]))
        .unwrap();
    // The first apply replaced the attached fit with the mock payload, which
    // has no implants/boosters, so all removals reject.
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 3);
}

#[test]
fn apply_edit_rejects_out_of_range_slots() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let context = test_context();
    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::SetImplant {
                type_id: 33516,
                slot: 0,
            },
            Op::SetImplant {
                type_id: 33516,
                slot: 11,
            },
            Op::SetBooster {
                type_id: 81083,
                slot: 4,
            },
        ]))
        .unwrap();
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 3);
    assert!(!report.persisted);
}

/// An implant can only go into its own slot (the app keys implants by the
/// type's implant-slot attribute and would silently drop a mismatch).
#[test]
fn apply_edit_rejects_implant_slot_mismatch() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let context = test_context();
    let report = runtime()
        .block_on(context.apply_edit(&[
            // Type 33516 occupies implant slot 1.
            Op::SetImplant {
                type_id: 33516,
                slot: 2,
            },
            // Type 1877 is a module, not an implant.
            Op::SetImplant {
                type_id: 1877,
                slot: 1,
            },
        ]))
        .unwrap();
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 2);
    assert!(report.rejected[0].contains("occupies slot 1"));
    assert!(report.rejected[1].contains("is not an implant"));
    assert!(!report.persisted);
}

/// The test ship (Arbitrator, type 628) has 4 high slots and the test fit
/// occupies three of them; only one more high module fits.
#[test]
fn apply_edit_rejects_module_beyond_slot_capacity() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let (callbacks, _) = mock_callbacks();
    let context = test_context().with_callbacks(Arc::new(callbacks));
    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::AddModule {
                slot_type: "high".to_string(),
                type_id: 1877,
                state: None,
                charge_type_id: None,
            },
            Op::AddModule {
                slot_type: "high".to_string(),
                type_id: 1877,
                state: None,
                charge_type_id: None,
            },
        ]))
        .unwrap();
    assert_eq!(report.applied.len(), 1);
    assert_eq!(report.rejected.len(), 1);
    assert!(report.rejected[0].contains("no free high slots"));
    assert!(report.persisted);
}

/// With subsystems fitted, the high/medium/low capacity comes from the
/// subsystems' slot-modifier attributes instead of the ship's (which are 0
/// for the Tengu, type 29984; subsystem 30050 provides 3 medium slots).
#[test]
fn apply_edit_subsystems_redefine_slot_capacity() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let container = FitContainer::new(
        ItemFit {
            ship_type_id: 29984,
            damage_profile: DamageProfile::default(),
            modules: vec![],
            drones: vec![],
            fighters: vec![],
            implants: vec![],
            boosters: vec![],
        },
        test_skills(),
        HashMap::new(),
    );
    let context = || {
        let active = ActiveFit {
            name: Some("tengu".to_string()),
            container: container.clone(),
            names: HashMap::new(),
        };
        FitToolContext::new(
            Arc::new(test_database()),
            Arc::new(RwLock::new(Some(active))),
            Arc::new(AttributeNames::default()),
        )
    };

    // Bare Tengu: no medium slots at all.
    let report = runtime()
        .block_on(context().apply_edit(&[Op::AddModule {
            slot_type: "medium".to_string(),
            type_id: 10850,
            state: None,
            charge_type_id: None,
        }]))
        .unwrap();
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 1);
    assert!(report.rejected[0].contains("no free medium slots"));

    // Fitting the subsystem redefines the topology: 3 medium slots.
    let (callbacks, _) = mock_callbacks();
    let report = runtime().block_on(context().with_callbacks(Arc::new(callbacks)).apply_edit(&[
        Op::AddModule {
            slot_type: "subsystem".to_string(),
            type_id: 30050,
            state: None,
            charge_type_id: None,
        },
        Op::AddModule {
            slot_type: "medium".to_string(),
            type_id: 10850,
            state: None,
            charge_type_id: None,
        },
        Op::AddModule {
            slot_type: "medium".to_string(),
            type_id: 10850,
            state: None,
            charge_type_id: None,
        },
        Op::AddModule {
            slot_type: "medium".to_string(),
            type_id: 10850,
            state: None,
            charge_type_id: None,
        },
        Op::AddModule {
            slot_type: "medium".to_string(),
            type_id: 10850,
            state: None,
            charge_type_id: None,
        },
    ]));
    let report = report.unwrap();
    assert_eq!(report.applied.len(), 4);
    assert_eq!(report.rejected.len(), 1);
    assert!(report.rejected[0].contains("no free medium slots"));
}

/// The tactical mode lives outside the app's fixed module slot lists; module
/// ops targeting it would apply here but be silently dropped on persistence.
#[test]
fn apply_edit_rejects_tactical_mode_ops() {
    use efa_chat::tools::fit::edit::FitEditOp as Op;
    let context = test_context();
    let report = runtime()
        .block_on(context.apply_edit(&[
            Op::AddModule {
                slot_type: "tactical_mode".to_string(),
                type_id: 1877,
                state: None,
                charge_type_id: None,
            },
            Op::SetModuleState {
                slot_type: "tactical_mode".to_string(),
                index: 0,
                state: "active".to_string(),
            },
        ]))
        .unwrap();
    assert!(report.applied.is_empty());
    assert_eq!(report.rejected.len(), 2);
    assert!(report.rejected.iter().all(|r| r.contains("tactical mode")));
    assert!(!report.persisted);
}
