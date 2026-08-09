---
title: Manual Topic
summary: Read a single manual page with breadcrumb navigation, in-page links, and feedback actions.
---

# Manual Topic

A manual topic is a single page of the manual. Reach it by browsing the [Manual Browser](efa://manual/pages/content/manual-browser), tapping a link inside another topic, or opening an in-app `efa://manual/...` deep link — links in announcements and other app content can point straight at a topic. See [In-App Links](efa://manual/sharing/deep-links).

## Reading a Topic

A breadcrumb bar at the top shows where the topic sits in the manual's folder tree; tap a breadcrumb entry to jump back to that folder. Below it the topic opens with its title and a short summary, followed by the full text of the page.

Links inside the text follow the in-app link rules: links to other manual topics open them in place, and `efa://manual/...` links navigate straight to the page they name. Relative links resolve within the manual, so following them stays inside the app. If a link points to a topic that does not exist, the tap is ignored and nothing breaks.

## Topic Actions

The app bar offers three actions:

- **Report an issue** — opens the report form with this page prefilled as the reported page. See [Manual Feedback](efa://manual/pages/content/manual-feedback).
- **View source on GitHub** — opens the page's source file in your browser.
- **Ask a question** — opens the question form. See asking in [Manual Feedback](efa://manual/pages/content/manual-feedback).

If the requested page does not exist, the app shows a "page not found" message, and if the manual content fails to load it offers a retry button.