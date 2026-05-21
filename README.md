# Filmist iOS

Native SwiftUI version of the Android Filmist app.

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
