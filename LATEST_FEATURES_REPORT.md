# EasySplit — Latest Features & Bug Fixes Summary Report

This report summarizes the latest features, architectural enhancements, UX improvements, and bug fixes implemented in EasySplit.

---

## 🚀 Key Feature Highlights

### 1. 📶 Full Offline Mode & Automatic Synchronization Engine
* **Offline Session Launch**: Users with an existing valid session (JWT token and cached user profile) can open and navigate the app offline without being forced to log out or re-authenticate.
* **Persistent Data Caching ([LocalCacheService](file:///c:/Users/arpit/Desktop/College/EasySplit%20Android/lib/core/services/local_cache_service.dart))**: Secure local disk persistence using `SharedPreferences` and `FlutterSecureStorage` for user profile data, groups, group details, expenses, settlements, and invitations.
* **Offline Expense Creation**: Allows users to add expenses while offline. Offline expenses appear immediately in the UI and are stored in a local pending queue.
* **Visual Sync Indicators**:
  * **Pending Sync (⟳)**: Unsynced expenses display a small sync icon beside the title.
  * **Failed Sync (⚠)**: If an upload fails, a warning icon appears beside the title with a tap-to-retry action.
* **Chronological Auto-Sync ([OfflineSyncService](file:///c:/Users/arpit/Desktop/College/EasySplit%20Android/lib/core/services/offline_sync_service.dart))**: Listens to device connectivity using `connectivity_plus`. When internet connectivity is restored, pending offline expenses are automatically uploaded in the exact order they were created.
* **Offline Feature Protection ([OfflineGuard](file:///c:/Users/arpit/Desktop/College/EasySplit%20Android/lib/core/utils/offline_guard.dart))**: Restricts server-dependent operations (Create Group, Invite Members, Accept/Reject Invitations, Settlement Requests, Approve/Reject Settlements, Lock Group, Generate Reports, Profile Updates) with high-visibility red floating alerts (`Colors.red[700]`) with white text.
* **Unauthenticated Offline Safeguard**: If an unauthenticated user opens the app offline, they are redirected to the login screen with the message: **"Internet connection required to sign in."**
* **Persistent Banner ([OfflineBanner](file:///c:/Users/arpit/Desktop/College/EasySplit%20Android/lib/shared/widgets/offline_banner.dart))**: Displays a top notification banner across tabs when offline:
  > **Offline Mode**  
  > Only expense addition is available. Changes will sync automatically when you're back online.

---

### 2. 💸 Settlement System & Duplicate Request Prevention
* **Backend Duplicate Prevention (`backend/routes/settlements.js`)**: Enforced server-side validation to prevent duplicate pending settlement requests for the same payer, receiver, and group combination.
* **User Feedback**: Returns a `400 Bad Request` with standard error messaging if a duplicate settlement request is attempted.

---

### 3. 📊 Activity Tab & UX Refinements
* **Streamlined Activity Timeline ([ActivityScreen](file:///c:/Users/arpit/Desktop/College/EasySplit%20Android/lib/features/activity/presentation/screens/activity_screen.dart))**: Refactored the Activity tab to display exclusively **Settlement Records** (Pending & Completed Settlements), removing recent expense clutter for cleaner auditability.
* **High-Contrast Alerts**: Redesigned snackbar alerts to use a solid red background with high-contrast white text (`Colors.white`) for dark/light mode readability.

---

## 🐛 Bug Fixes & Technical Improvements

| Area | Issue Description | Fix / Resolution |
| :--- | :--- | :--- |
| **Authentication** | Network disconnections were incorrectly clearing secure session tokens and logging out users. | Updated `restoreSession()` in [AuthSessionService](file:///c:/Users/arpit/Desktop/College/EasySplit%20Android/lib/core/services/auth_service.dart) to only clear sessions on explicit backend `401 Unauthorized` responses when online. |
| **Build Release** | Release build compilation error (`Type 'SplitType' not found` & `OtpTextField not defined`). | Added missing imports for `AppConstants` (`SplitType`) in `expenses_provider.dart` and `AppTextField` (`OtpTextField`) in `otp_screen.dart`. |
| **Data Sync** | Local pending expenses could duplicate upon reconnection. | Enhanced pending queue item replacement logic to match server-returned IDs and clean up pending cache upon successful POST responses. |

---

## 🧪 Verification & Build Status

* **Unit & Model Tests**: Verified test suite ([test/offline_mode_test.dart](file:///c:/Users/arpit/Desktop/College/EasySplit%20Android/test/offline_mode_test.dart)) with `flutter test`:
  `00:00 +2: All tests passed!`
* **Code Generation**: Executed `build_runner` with 0 errors (`Built with build_runner in 41s`).
* **Git Remote Status**: All commits (`feat: Implement Offline Mode...`, `fix: Add missing imports...`, `style: Update offline guard snackbar...`) pushed to branch `main` on GitHub (`https://github.com/arpit-thombe2005/EasySplit.git`).
