# App Router

EFA uses `AutoRoute` package for routing.
See [AutoRoute Documentation](https://pub.dev/packages/auto_route) for more details.

## Page Structure

All UI pages are defined in `lib/pages` folder, just like the `App` structure in Next.js.
However, not all pages are routable, some pages are only
used as sub-pages (e.g., tabs, navigator tabs) or dialogs.

## Router Configuration

The router configuration is defined in [`lib/pages/router.dart`](../../lib/pages/router.dart).
Thanks to AutoRoute, we can define the routes in a declarative way using annotations.

To add a new route, simply add a new entry in the `@RoutePage` annotation, like:
```dart
@RoutePage()
class NewPage extends StatelessWidget {
  const NewPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Page')),
      body: const Center(child: Text('This is a new page')),
    );
  }
}
```

**Note:** After adding new routes, you must run dart build runner:
```bash
./x gen dart # one-shot command to run build runner
./x gen dart -w # watch mode to auto-generate code on file changes
```

Then, the page configuration will be generated in `lib/pages/router.gr.dart`.

**Note:** You must import your pages in `lib/pages/router.dart` to make them routable.

## Navigating Between Pages

See [Navigation Documentation](https://pub.dev/packages/auto_route#navigating-between-screens)
for more details.
