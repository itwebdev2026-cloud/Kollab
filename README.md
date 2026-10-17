# Kollab

Flutter web app for creators and businesses to discover each other, manage profiles, and chat.

## Run

From this directory, run `flutter run -d chrome`.

## Firebase

The web app is configured for Firebase project `kollab-6342d`. Enable Email/Password and Google providers in Firebase Authentication. Firestore rules live in `firestore.rules`; deploy them with `firebase deploy --only firestore:rules --project=kollab-6342d`.

## Firestore schema

- `users/{uid}` stores account email, role (`creator` or `business`), and timestamps.
- `creators/{uid}` stores creator profile details, social links, skills, service rates, and a compressed profile picture.
- `businesses/{uid}` stores business profile details.
- `conversations/{uidA__uidB}` stores the sorted participant IDs, participant names, last message, and timestamps. Only participants can access a conversation.
- `conversations/{uidA__uidB}/messages/{messageId}` stores sender ID, message text, and creation time. Messages are immutable after sending.

Creator discovery reads from Firestore. Sample creators are for presentation only and cannot be messaged.
