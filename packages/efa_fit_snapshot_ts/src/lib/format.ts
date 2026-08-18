/** Equivalent of Dart's `num.toStringAsMaxDecimals`. */
export function toMaxDecimals(value: number, maxDecimals: number): string {
    return value.toFixed(maxDecimals);
}

/** Thousands-grouped rounded integer, locale-independent (matches Dart `commaSeparated`). */
export function commaSeparated(value: number): string {
    return Math.round(value)
        .toString()
        .replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/** Equivalent of Dart's `Duration.format()`: `HH:MM:SS`, sign-prefixed when negative. */
export function formatDuration(totalSeconds: number): string {
    const sign = totalSeconds < 0 ? "-" : "";
    const s = Math.abs(Math.round(totalSeconds));
    const pad = (n: number) => String(n).padStart(2, "0");
    return `${sign}${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`;
}
