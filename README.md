# XCEL – Build Guide

## Prerequisites
- Flutter 3.16+ installed (`flutter --version`)
- Android SDK with API 34 (`targetSdk`)
- `google-services.json` already placed at `android/app/google-services.json` ✓

---

## 1. Set flutter.sdk in local.properties

Edit `android/local.properties`:

```
flutter.sdk=/home/yourname/flutter      # Linux/macOS
flutter.sdk=C:\\flutter                  # Windows
sdk.dir=/home/yourname/Android/Sdk
```

---

## 2. Install dependencies

```bash
flutter pub get
```

---

## 3. Firebase – Firestore setup

Create these Firestore collections (Firebase Console → Firestore):

### `users` collection
Document ID = username (String)

| Field      | Type      | Notes                        |
|------------|-----------|------------------------------|
| password   | String    | Plain text password          |
| validity   | Timestamp | Expiry date/time             |
| deviceId   | String    | null until first login       |

### `messages` collection
Auto-generated document IDs

| Field        | Type      | Notes                              |
|--------------|-----------|------------------------------------|
| userId       | String    | Target username                    |
| adminMessage | String    | Message from admin                 |
| timestamp    | Timestamp | Use FieldValue.serverTimestamp()   |
| reply        | String    | null until user replies            |

### Firestore security rules (for testing – tighten for production)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

---

## 4. Shizuku / File Access

The app requires access to `/storage/emulated/0/Android/data/`.  
On Android 11+, grant it via:
- **Settings → Apps → XCEL → Permissions → Files and media → Allow management of all files**
- Or via Shizuku ADB: `appops set xcel.mujahi MANAGE_EXTERNAL_STORAGE allow`

---

## 5. Build release APK

```bash
# Debug APK (quick, no signing needed)
flutter build apk --debug

# Release APK (optimised)
flutter build apk --release

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Install on device

```bash
flutter install
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 7. Admin credentials

| Item            | Value          |
|-----------------|----------------|
| Admin password  | `Mujahi@admin` |

Access: Profile screen → Admin Access button → enter password.

---

## 8. Auto Turn-Off

When **TURN ON** is pressed, a `Workmanager` one-shot task is scheduled for
**4 hours** later. It runs the turn-off rename logic and clears the `isOn`
SharedPreferences flag even when the app is closed.

Manual **TURN OFF** cancels the scheduled task.
