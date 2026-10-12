# Kollab (MVP slice)
Run: `flutter create . --platforms=android,ios` (once, to generate platform folders), then `flutter run`.
Works offline with demo auth + sample creators. For Firebase: `flutterfire configure`, set `useFirebase = true` in lib/main.dart.

Logo: save your file as assets/logo.png and uncomment the assets block in pubspec.yaml. Colors live in lib/core/brand.dart.

Firestore plan: users/{uid}{role}, creators/{uid}{name,username,city,niches[],types[],followers,price,availability,verified},
creators/{uid}/portfolio/{id}, businesses/{uid}, campaigns/{id}, requests/{id}{from,to,status}, chats/{id}/messages/{id}.
Keep matchScore in lib/features/creator.dart client-side for MVP; move to a Cloud Function when data grows.
