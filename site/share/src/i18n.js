(() => {
    const STRINGS = {
        en: {
            title: "Open fit link",
            heading: "Open this fit",
            description:
                "This link contains an EVE Fit Assistant fit. Choose where to open it. The fit is imported as a copy; your existing fits are not modified.",
            optionApp: "Open in app",
            optionAppDesc: "Import into the installed EVE Fit Assistant app.",
            optionWeb: "Open in web app",
            optionWebDesc: "Import into EVE Fit Assistant running in this browser.",
            optionNightly: "Open in nightly web app",
            optionNightlyDesc: "Preview build of the web app. May be unstable.",
            rememberChoice: "Always use this option",
            redirecting: "Redirecting…",
            cancelRedirect: "Cancel automatic redirect",
            resetPreference: "Reset my choice",
            downloadTitle: "App not installed?",
            downloadDesc:
                "Nothing opened. Install EVE Fit Assistant first, then open this link again.",
            downloadButton: "Download EVE Fit Assistant",
            notFoundTitle: "Link not found",
            notFoundDesc: "This link is not a valid fit link. Ask the sender for a new one.",
            langToggle: "中文",
        },
        zh: {
            title: "打开配置链接",
            heading: "打开此配置",
            description:
                "此链接包含一个 EVE Fit Assistant 配置。请选择打开方式。配置将作为副本导入，不会修改现有配置。",
            optionApp: "在应用中打开",
            optionAppDesc: "导入到已安装的 EVE Fit Assistant 应用。",
            optionWeb: "在网页版中打开",
            optionWebDesc: "导入到浏览器中运行的 EVE Fit Assistant。",
            optionNightly: "在每日构建网页版中打开",
            optionNightlyDesc: "网页版的预览构建，可能不稳定。",
            rememberChoice: "始终使用此方式",
            redirecting: "正在重定向……",
            cancelRedirect: "取消自动重定向",
            resetPreference: "重置我的选择",
            downloadTitle: "尚未安装应用？",
            downloadDesc: "没有应用响应。请先安装 EVE Fit Assistant，然后重新打开此链接。",
            downloadButton: "下载 EVE Fit Assistant",
            notFoundTitle: "链接不存在",
            notFoundDesc: "此链接不是有效的配置链接。请向发送者索取新的链接。",
            langToggle: "English",
        },
    };

    const STORAGE_KEY = "efa-share-lang";

    function negotiate() {
        try {
            const stored = localStorage.getItem(STORAGE_KEY);
            if (stored === "en" || stored === "zh") return stored;
        } catch (_) {
            // localStorage unavailable; fall through to negotiation.
        }
        const nav = (navigator.language || "en").toLowerCase();
        return nav.startsWith("zh") ? "zh" : "en";
    }

    window.EfaShareI18n = { STRINGS, STORAGE_KEY, negotiate };
})();
