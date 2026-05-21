# Filmist iOS

Native SwiftUI version of the Android Filmist app.

## Support

Filmist is a film photography log app for tracking film stocks, rolls, cameras, development status, backups, and attached photos.

For app support, bug reports, feedback, or feature requests, please open an issue in this GitHub repository. Include your iPhone model, iOS version, app version, and a short description of what happened.

If you need help with backup, restore, iCloud sync, importing a backup file, adding film, loading a roll, editing film, or attaching photos, create a GitHub issue and describe the screen or workflow where you need help.

## Features

- Track film stock metadata: brand, model, ISO, size, frames per roll, roll count, expiry date, and optional logo.
- Create individual roll records from each stock entry.
- Record status changes with explicit dates: in storage, loaded, finished, in development, developed.
- Record which camera body and lens a roll was loaded into.
- Attach developed photos to a specific roll so each image stays linked to its film.
- Back up and restore the film log and saved images with iCloud.
- Export and import one portable backup file as a manual fallback.

Open `FilmAppiOS.xcodeproj` in Xcode and run the `FilmAppiOS` scheme on an iPhone simulator or device.

## iCloud setup

The project includes an iCloud entitlements file. In Xcode, select your paid Apple developer team, then confirm the `iCloud` capability is enabled for the `FilmAppiOS` target with `iCloud Documents` checked.

The Settings tab also includes portable JSON export/import as a manual fallback.
