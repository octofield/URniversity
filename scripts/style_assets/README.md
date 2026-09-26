# App style assets (Android)

`generate.py` produces everything Android draws in the app style before or
outside Flutter (docs/system_design.md §3-R):

- launcher icons per style — adaptive foregrounds, legacy mipmaps, adaptive XML
- splash logos and `values-v31/launch_styles.xml` (`LaunchTheme.<Style>`)
- the home screen widget: `values/widget_style_colors.xml` and its drawables

Linen's assets are the originals and are never regenerated.

## When to run

Whenever a palette changes. `palettes.json` must equal `kStylePalettes` in
`src/lib/core/theme/app_styles.dart`; `src/test/style_assets_test.dart` fails
until both and the generated files agree.

## How

```
pip install pillow
python scripts/style_assets/generate.py
```

Then commit the generated files under `src/android/app/src/main/res`.

Icons are recoloured with a gradient map: each pixel's brightness is looked up
on a ramp of the style's colours (ANCHORS in the script are the brightness of
the original's ink, path, glow, background and symbols), so the artwork is
unchanged and only its colours follow the style.

## Adding a style

1. Add it to `AppStyle` / `kStylePalettes` and to `palettes.json`.
2. Run the script.
3. Add its `activity-alias` in `AndroidManifest.xml`, its name to `STYLES` and
   `setSplash` in `MainActivity.kt`, and its branch in `WidgetStyle.kt`.
4. `flutter test test/style_assets_test.dart` checks all of the above.
