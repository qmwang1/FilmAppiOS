# Film Log iOS

Native SwiftUI version of the Android Film Log app.

## Features

- Track film stock metadata: brand, model, ISO, size, frames per roll, roll count, expiry date, and optional logo.
- Create individual roll records from each stock entry.
- Record status changes with explicit dates: in storage, loaded, finished, in development, developed.
- Record which camera body and lens a roll was loaded into.
- Attach developed photos to a specific roll so each image stays linked to its film.
- Export and import one portable backup file containing the local film log and saved images.

Open `FilmAppiOS.xcodeproj` in Xcode and run the `FilmAppiOS` scheme on an iPhone simulator or device.

## Backup

The backup feature does not use Apple's iCloud entitlement, so it works with a personal development team. Use Settings -> Export Backup File, then save the JSON backup file to iCloud Drive, Files, AirDrop, or another location. Use Settings -> Import Backup File to restore it later.
