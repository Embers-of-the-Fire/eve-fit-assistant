export type Locale = "en" | "zh";
export type TranslationKey = keyof typeof en;

export const en = {
    "nav.features": "Features",
    "nav.download": "Download",
    "nav.about": "About",
    "nav.report": "Report",
    "nav.manual": "Manual",
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
    "cta.manual": "Read the Manual",

    "footer.trademark_1":
        "EVE Online and the EVE logo are the registered trademarks of CCP hf. All rights are reserved worldwide.",
    "footer.trademark_2":
        "All other trademarks are the property of their respective owners. EVE Fit Assistant is a third-party tool and is not endorsed by CCP hf.",

    "report.heading": "Report an Issue",
    "report.description":
        "Found a bug or have a feature idea? Let us know — submissions create GitHub issues the team can track.",

    "report.bug.title": "Bug Report",
    "report.bug.description":
        "Something isn't working right? Describe the problem and steps to reproduce it.",

    "report.feature.title": "Feature Request",
    "report.feature.description":
        "Have an idea to improve the app? Tell us what you need and why it matters.",

    "report.form.title": "Title",
    "report.form.title.placeholder": "Short, descriptive title for this submission",
    "report.form.bug.prefix": "[Bug]: ",
    "report.form.feature.prefix": "[Feature]: ",

    "report.form.required": "(required)",
    "report.form.optional": "(optional)",
    "report.form.do_not_attach": "Do not attach",
    "report.form.attach_extras": "Attach additional details",
    "report.form.submit": "Submit",
    "report.form.submitting": "Submitting...",

    "report.form.bug.summary": "Summary",
    "report.form.bug.summary.placeholder": "Briefly describe what went wrong",
    "report.form.bug.steps": "Steps to Reproduce",
    "report.form.bug.steps.placeholder":
        "1. Open the app\n2. Navigate to ...\n3. Observe the issue",
    "report.form.bug.expected": "Expected Behavior",
    "report.form.bug.expected.placeholder": "What should have happened",
    "report.form.bug.actual": "Actual Behavior",
    "report.form.bug.actual.placeholder": "What actually happened",
    "report.form.bug.platform": "Platform",
    "report.form.bug.version": "App Version",
    "report.form.bug.version.placeholder": "e.g. 0.1.0",
    "report.form.bug.logs": "Logs / Screenshots / Extra Context",
    "report.form.bug.logs.placeholder":
        "Paste any relevant logs, error messages, or describe additional context",

    "report.form.feature.problem": "Problem to Solve",
    "report.form.feature.problem.placeholder": "What problem are you trying to solve?",
    "report.form.feature.proposal": "Proposed Solution",
    "report.form.feature.proposal.placeholder": "Describe your idea in detail",
    "report.form.feature.impact": "Use Case / Impact",
    "report.form.feature.impact.placeholder": "Why is this important? Who would benefit?",
    "report.form.feature.alternatives": "Alternatives Considered",
    "report.form.feature.alternatives.placeholder":
        "Any workarounds or alternative approaches you've thought of",
    "report.form.feature.extra": "Mockups / References / Extra Context",
    "report.form.feature.extra.placeholder":
        "Links to mockups, references, or any additional context",

    "report.form.labels": "Labels",
    "report.form.labels.placeholder": "Comma-separated labels, e.g. T-Bug, V-Needs Triage",
    "report.form.metadata": "Metadata",
    "report.form.metadata.key": "Key",
    "report.form.metadata.value": "Value",
    "report.form.metadata.add": "Add row",
    "report.form.metadata.remove": "Remove",
    "report.form.metadata.key.placeholder": "e.g. os_version",
    "report.form.metadata.value.placeholder": "e.g. Android 14",

    "report.form.platform.android": "Android",
    "report.form.platform.ios": "iOS",
    "report.form.platform.windows": "Windows 10/11",
    "report.form.platform.linux": "Linux",
    "report.form.platform.other": "Other",

    "report.form.success.title": "Submitted!",
    "report.form.success.view_on_github": "View on GitHub",

    "report.form.error.title": "Something went wrong",
    "report.form.error.network": "Network error — please check your connection and try again.",

    "report.form.back": "Back to Reports",

    "download.title": "EVE Fit Assistant — Download & Installation",
    "download.meta_description":
        "Download the latest EVE Fit Assistant APK for Android, view all releases on GitHub, or build from source.",
    "download.heading": "Get EVE Fit Assistant",
    "download.subtitle": "Choose the installation method that works best for you.",
    "download.android.title": "Android APK",
    "download.android.desc":
        "Native Android app built with Flutter and a Rust fitting engine. Requires Android 8.0+ (API 26).",
    "download.android.apk": "Download Latest APK",
    "download.android.requirements": "Android 8.0+ required",
    "download.all_releases": "View All Releases on GitHub →",
    "download.source.title": "Build from Source",
    "download.source.desc":
        "Clone the repository and follow the build instructions. Requires Flutter, Rust, and Nix.",
    "download.source.github": "View on GitHub",
    "download.ios.title": "iOS Build",
    "download.ios.desc":
        "iOS is supported in the same Flutter codebase. Build from source with Xcode. A TestFlight release may be available in the future.",
    "download.ios.build": "Build with Xcode",
    "download.loading": "Checking for latest release...",
    "download.no_release": "No releases available yet",
    "download.no_release_desc":
        "The first release hasn't been published yet. Watch the repository for updates.",
    "download.error": "Unable to load release info",
    "download.error_desc":
        "The release server could not be reached. You can check for releases directly on GitHub.",
    "download.error_github": "View Releases on GitHub",
    "download.channel": "Channel:",
    "download.recommended": "Recommended",
    "download.detected": "Detected:",
};

export const zh: Record<TranslationKey, string> = {
    "nav.features": "功能特性",
    "nav.download": "下载",
    "nav.about": "关于",
    "nav.report": "反馈",
    "nav.manual": "使用手册",
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
    "cta.manual": "阅读使用手册",

    "footer.trademark_1": "EVE Online 和 EVE 标志是 CCP hf 的注册商标。保留所有权利。",
    "footer.trademark_2":
        "所有其他商标均为其各自所有者的财产。EVE Fit Assistant 是第三方工具，未经 CCP hf 认可。",

    "report.heading": "反馈问题",
    "report.description":
        "发现了 Bug 或有功能建议？告诉我们 — 提交的内容会创建 GitHub Issue 供团队跟踪。",

    "report.bug.title": "反馈 Bug",
    "report.bug.description": "有什么功能无法正常工作？描述问题及复现步骤。",

    "report.feature.title": "功能请求",
    "report.feature.description": "有改进应用的想法？告诉我们你需要的功能以及为什么重要。",

    "report.form.title": "标题",
    "report.form.title.placeholder": "简短的描述性标题",
    "report.form.bug.prefix": "[Bug]: ",
    "report.form.feature.prefix": "[Feature]: ",

    "report.form.required": "（必填）",
    "report.form.optional": "（选填）",
    "report.form.do_not_attach": "不附加",
    "report.form.attach_extras": "附加额外信息",
    "report.form.submit": "提交",
    "report.form.submitting": "提交中...",

    "report.form.bug.summary": "概述",
    "report.form.bug.summary.placeholder": "简要描述出了什么问题",
    "report.form.bug.steps": "复现步骤",
    "report.form.bug.steps.placeholder": "1. 打开应用\n2. 进入 ...\n3. 观察问题",
    "report.form.bug.expected": "预期行为",
    "report.form.bug.expected.placeholder": "原本应该发生什么",
    "report.form.bug.actual": "实际行为",
    "report.form.bug.actual.placeholder": "实际发生了什么",
    "report.form.bug.platform": "平台",
    "report.form.bug.version": "应用版本",
    "report.form.bug.version.placeholder": "例如 0.1.0",
    "report.form.bug.logs": "日志 / 截图 / 其他补充",
    "report.form.bug.logs.placeholder": "粘贴相关日志、错误信息或描述额外上下文",

    "report.form.feature.problem": "要解决的问题",
    "report.form.feature.problem.placeholder": "你想解决什么问题？",
    "report.form.feature.proposal": "期望方案",
    "report.form.feature.proposal.placeholder": "详细描述你的想法",
    "report.form.feature.impact": "使用场景 / 影响",
    "report.form.feature.impact.placeholder": "这为什么重要？谁会受益？",
    "report.form.feature.alternatives": "替代方案",
    "report.form.feature.alternatives.placeholder": "你考虑过的变通方案或替代方法",
    "report.form.feature.extra": "原型 / 参考 / 其他补充",
    "report.form.feature.extra.placeholder": "原型链接、参考资料或任何补充上下文",

    "report.form.labels": "标签",
    "report.form.labels.placeholder": "逗号分隔的标签，例如 T-Bug, V-Needs Triage",
    "report.form.metadata": "元数据",
    "report.form.metadata.key": "键",
    "report.form.metadata.value": "值",
    "report.form.metadata.add": "添加行",
    "report.form.metadata.remove": "移除",
    "report.form.metadata.key.placeholder": "例如 os_version",
    "report.form.metadata.value.placeholder": "例如 Android 14",

    "report.form.platform.android": "Android",
    "report.form.platform.ios": "iOS",
    "report.form.platform.windows": "Windows 10/11",
    "report.form.platform.linux": "Linux",
    "report.form.platform.other": "其他",

    "report.form.success.title": "提交成功！",
    "report.form.success.view_on_github": "在 GitHub 上查看",

    "report.form.error.title": "出了点问题",
    "report.form.error.network": "网络错误 — 请检查网络连接后重试。",

    "report.form.back": "返回反馈",

    "download.title": "EVE Fit Assistant — 下载与安装",
    "download.meta_description":
        "下载最新的 EVE Fit Assistant APK（Android），在 GitHub 上查看所有版本，或从源码构建。",
    "download.heading": "获取 EVE Fit Assistant",
    "download.subtitle": "选择最适合你的安装方式。",
    "download.android.title": "Android APK",
    "download.android.desc":
        "基于 Flutter 和 Rust 装配引擎的原生 Android 应用，需要 Android 8.0+（API 26）。",
    "download.android.apk": "下载最新 APK",
    "download.android.requirements": "需要 Android 8.0+",
    "download.all_releases": "在 GitHub 上查看所有版本 →",
    "download.source.title": "从源码构建",
    "download.source.desc": "克隆仓库并按照构建说明操作。需要 Flutter、Rust 和 Nix。",
    "download.source.github": "在 GitHub 上查看",
    "download.ios.title": "iOS 构建",
    "download.ios.desc":
        "同一 Flutter 代码库支持 iOS。使用 Xcode 从源码构建。未来可能会提供 TestFlight 版本。",
    "download.ios.build": "使用 Xcode 构建",
    "download.loading": "正在检查最新版本...",
    "download.no_release": "暂无可用版本",
    "download.no_release_desc": "首个版本尚未发布。关注仓库以获取更新。",
    "download.error": "无法加载版本信息",
    "download.error_desc": "无法连接版本服务器。你可以直接在 GitHub 上查看版本。",
    "download.error_github": "在 GitHub 上查看版本",
    "download.channel": "频道：",
    "download.recommended": "推荐",
    "download.detected": "检测到：",
};
