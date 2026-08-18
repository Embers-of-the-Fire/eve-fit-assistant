export const en = {
    "nav.fits": "Fits",
    "nav.account": "Account",
    "fits.title": "Fit Snapshots",
    "fits.loading": "Loading fits…",
    "fits.error": "Failed to load fits.",
    "fits.empty": "No fits uploaded yet.",
    "fits.untitled": "Untitled fit",
    "fits.uploaded": "Uploaded",
    "fits.lastModified": "Last modified",
    "fit.snapshotData": "Snapshot data",
    "fit.notFound": "Snapshot not found.",
    "threads.title": "Discussion",
    "threads.comingSoon": "Discussion threads are coming soon.",
    "account.title": "Account",
    "account.placeholder": "Account features are coming soon.",
} as const;

export type Locale = "en" | "zh";
export type TranslationKey = keyof typeof en;

export const zh: Record<TranslationKey, string> = {
    "nav.fits": "配置",
    "nav.account": "账号",
    "fits.title": "配置快照",
    "fits.loading": "正在加载配置…",
    "fits.error": "加载配置失败。",
    "fits.empty": "还没有上传的配置。",
    "fits.untitled": "未命名配置",
    "fits.uploaded": "上传于",
    "fits.lastModified": "最后修改",
    "fit.snapshotData": "快照数据",
    "fit.notFound": "快照不存在。",
    "threads.title": "讨论",
    "threads.comingSoon": "讨论功能即将上线。",
    "account.title": "账号",
    "account.placeholder": "账号功能即将上线。",
};
