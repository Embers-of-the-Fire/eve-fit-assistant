export type Locale = "en" | "zh";
export type TranslationKey = keyof typeof en;

export const en = {
    "nav.features": "Features",
    "nav.about": "About",
    "nav.get_started": "Get Started",

    "brand.name": "EVE Fit Assistant",

    "home.title": "EVE Fit Assistant — Cross-Platform Ship Fitting for New Eden",
    "home.meta_description":
        "EFA is a cross-platform mobile EVE fitting tool. Edit fits offline, inspect items, check skill profiles — powered by Flutter and a native Rust backend.",

    "hero.badge": "Alpha — Now in Development",
    "hero.heading_1": "Cross-Platform Ship Fitting",
    "hero.heading_2": "for New Eden",
    "hero.description":
        "A mobile fitting tool built with Flutter and a native Rust backend. Edit fits offline, inspect items, and load character skill profiles — all backed by versioned data bundles with incremental patching.",
    "hero.get_started": "Get Started",
    "hero.learn_more": "Learn More",

    "features.heading": "Fit Smarter, Fly Better",
    "features.subtitle": "Everything you need to perfect your ship configuration — on the go.",

    "features.local_fit.title": "Local Fit Editing",
    "features.local_fit.desc":
        "Create, edit, and experiment with ship fittings directly on your device. No server connection needed — all calculations run locally.",

    "features.item_detail.title": "Item Detail Inspection",
    "features.item_detail.desc":
        "Browse the complete EVE item database with full statistics, attributes, fitting requirements, and meta information at your fingertips.",

    "features.skill_profiles.title": "Character Skill Profiles",
    "features.skill_profiles.desc":
        "Load your character skills to see exactly how training affects module performance, fitting requirements, and overall ship capabilities.",

    "features.rust_backend.title": "Rust-Powered Backend",
    "features.rust_backend.desc":
        "Fitting calculations run natively in Rust via flutter_rust_bridge — delivering speed, accuracy, and offline reliability.",

    "features.offline_data.title": "Offline Data Bundles",
    "features.offline_data.desc":
        "Static game data shipped as versioned bundles with incremental patching. Stay current without re-downloading the entire dataset.",

    "features.cross_platform.title": "Cross-Platform",
    "features.cross_platform.desc":
        "Full Android support with official APK releases. iOS build support included — a single Flutter codebase targeting both platforms.",

    "architecture.label": "Architecture",
    "architecture.heading": "Flutter + Rust, Built to Last",
    "architecture.description":
        "The frontend is built with Flutter for a smooth cross-platform experience. The fitting engine runs natively in Rust via flutter_rust_bridge — keeping calculations fast, accurate, and available offline. Python handles data processing, while Nix provides a reproducible dev environment. Source-insensitive by design: the app never cares where the data comes from.",
    "architecture.tech_flutter": "Flutter & Dart",
    "architecture.tech_rust": "Rust backend",
    "architecture.tech_python": "Python data pipeline",
    "architecture.tech_offline": "Offline-first",
    "architecture.tech_oss": "Open-source",

    "cta.heading": "Ready to fit your ship?",
    "cta.description":
        "EVE Fit Assistant is open-source and under active development. Follow the project on GitHub or build it yourself.",
    "cta.github": "View on GitHub",
    "cta.qq_group": "Join QQ Group",

    "footer.trademark_1":
        "EVE Online and the EVE logo are the registered trademarks of CCP hf. All rights are reserved worldwide.",
    "footer.trademark_2":
        "All other trademarks are the property of their respective owners. EVE Fit Assistant is a third-party tool and is not endorsed by CCP hf.",
};

export const zh: Record<TranslationKey, string> = {
    "nav.features": "功能特性",
    "nav.about": "关于",
    "nav.get_started": "开始使用",

    "brand.name": "EVE Fit Assistant",

    "home.title": "EVE Fit Assistant — 新伊甸跨平台舰船配置工具",
    "home.meta_description":
        "EFA 是一款跨平台移动端 EVE 舰船装配工具。离线编辑配置、查阅物品详情、加载角色技能 — 由 Flutter 和原生 Rust 后端提供支持。",

    "hero.badge": "Alpha — 开发中",
    "hero.heading_1": "跨平台舰船配置",
    "hero.heading_2": "为 新伊甸 打造",
    "hero.description":
        "一款由 Flutter 和原生 Rust 后端构建的移动端装配工具。离线编辑配置、查阅物品详情、加载角色技能 — 全部基于版本化数据包与增量更新。",
    "hero.get_started": "开始使用",
    "hero.learn_more": "了解更多",

    "features.heading": "更智能的装配，更好的飞行",
    "features.subtitle": "随时随地完善你的舰船配置所需的一切。",

    "features.local_fit.title": "本地装配编辑",
    "features.local_fit.desc":
        "直接在设备上创建、编辑和尝试舰船装配。无需服务器连接 — 所有计算均在本地运行。",

    "features.item_detail.title": "物品详情查阅",
    "features.item_detail.desc":
        "浏览完整的 EVE 物品数据库，包括完整统计数据、属性、装配需求和元信息，触手可及。",

    "features.skill_profiles.title": "角色技能档案",
    "features.skill_profiles.desc":
        "加载角色技能，精确查看训练如何影响装备性能、装配需求和舰船整体能力。",

    "features.rust_backend.title": "Rust 驱动后端",
    "features.rust_backend.desc":
        "装配计算通过 flutter_rust_bridge 以原生 Rust 运行 — 提供卓越的速度、准确度和离线可靠性。",

    "features.offline_data.title": "离线数据包",
    "features.offline_data.desc":
        "静态游戏数据以版本化数据包形式发布，支持增量补丁。无需重新下载整个数据集即可保持最新。",

    "features.cross_platform.title": "跨平台",
    "features.cross_platform.desc":
        "全面支持 Android，提供官方 APK 发布。包含 iOS 构建支持 — 单一 Flutter 代码库同时覆盖双平台。",

    "architecture.label": "架构",
    "architecture.heading": "Flutter + Rust，经久耐用",
    "architecture.description":
        "前端采用 Flutter 构建，提供流畅的跨平台体验。装配引擎通过 flutter_rust_bridge 以原生 Rust 运行 — 保持计算快速、准确且可离线使用。Python 处理数据处理，Nix 提供可复现的开发环境。设计上不关心数据来源：应用从不在意数据来自何处。",
    "architecture.tech_flutter": "Flutter & Dart",
    "architecture.tech_rust": "Rust 后端",
    "architecture.tech_python": "Python 数据处理",
    "architecture.tech_offline": "离线优先",
    "architecture.tech_oss": "开源",

    "cta.heading": "准备好装配你的舰船了吗？",
    "cta.description":
        "EVE Fit Assistant 完全开源，正在积极开发中。在 GitHub 上关注项目或自行构建。",
    "cta.github": "在 GitHub 上查看",
    "cta.qq_group": "加入 QQ 群",

    "footer.trademark_1": "EVE Online 和 EVE 标志是 CCP hf 的注册商标。保留所有权利。",
    "footer.trademark_2":
        "所有其他商标均为其各自所有者的财产。EVE Fit Assistant 是第三方工具，未经 CCP hf 认可。",
};
