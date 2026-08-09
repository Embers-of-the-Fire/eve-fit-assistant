---
title: Collect Logs
summary: Filter app log files by time range and share the selected ones as a zip.
---

# Collect Logs

The Collect Logs page (Developer Settings → Collect Logs) lets you pick log files and share them with the development team. It requires [Developer Mode](efa://manual/settings/developer-mode) and is not available on the web.

At the top is the **quick filter** row of time ranges: last hour, 24 hours, 7 days, 30 days, or all. Choosing a range automatically selects the log files modified within that window.

The list below shows every log file sorted by modification time (newest first); each row shows the file name, last-modified time, and size, with a checkbox deciding whether the file is included. The file currently being written, **latest.log**, is marked as active. If you manually check or uncheck a file, the filter switches back to "all".

The bottom bar shows the number of selected files and their total size. Tapping the **Share** button packs the selected logs into a single zip and opens the system share sheet, so you can send it along with a [feedback report](efa://manual/pages/settings/report-feedback). See [Feedback & Logs](efa://manual/settings/feedback-and-logs) for the full workflow.