## How to run the Happs app
1. Pull files
2. Using Emulator of choice, run a virtual device
3. Run main.dart in debug

## Inspiration
University campuses are full of people, yet it can still feel surprisingly hard to organise spontaneous activities. It is almost **impossible** to memorise all your friends' schedules, and even then there is no way to know if or where they are on campus. Students often want to do simple things like grab food, play badminton, or start a quick study session, but coordinating it through group chats is inefficient and often results in crickets. 🦗 🦗

We built **Happs** to solve this problem by making it easy to see who is nearby and organise spontaneous activities with minimal effort.

## What it does
Happs is a social app that helps university students coordinate spontaneous activities in real time. Users can see which friends are currently on campus, check their availability status, and quickly create or join events — called "happs" — such as food runs, study sessions, or sports activities. The app uses live location sharing within a campus geofence, meaning location is only active on campus, keeping things both useful and private. Happs also allows you to see what people are doing on campus based on their class schedule with the help of status toggles — including an invisible mode that hides your location.

## How we built it
The app is built with Flutter for **cross-platform Android and iOS support**, backed entirely by Firebase for authentication, live data, storage, and push notifications. Core features include a live friend map with campus geofencing, social connection flows, group management, and preference-based matching — all tied together with a lightweight layered architecture designed for speed.

**Frontend:**
Built entirely in Flutter (Dart, SDK ^3.11.1) targeting Android and iOS from a single codebase. The UI spans 13 screens covering authentication, onboarding, a live map/dashboard, profiles, preferences, friends, and groups.

State is managed with Flutter's built-in StatefulWidget and StreamBuilder patterns, with Firestore streams driving real-time updates — friend locations, group membership, and user status all update live.

Notable packages: google_maps_flutter, flutter_polyline_points, intl_phone_field, image_picker, flutter_contacts, permission_handler.

**Backend:**
Firebase handles the entire backend with no server infrastructure to manage.

* Auth — Email/password, Google OAuth, and phone OTP. An AuthWrapper listens to authStateChanges() and creates a Firestore user document on first login.
* Firestore — Three collections: users (profile, location, status, friends), happs (events/activities), and groups. All accessed through a repository layer (UserRepository, HappRepository, GroupRepository).
* Storage — Profile pictures uploaded at 512×512 / 80% JPEG; download URL saved to Firestore and Auth profile.
* FCM — FCM tokens stored at sign-in for push notification delivery.

## Challenges we ran into
One of the main challenges our team faced was learning Flutter and adapting to a new development framework. Since several team members had little or no prior experience with Flutter or Dart, we had to spend time learning the structure of the framework, understanding widget-based UI design, and managing application state. This slowed early development as we experimented with layouts, navigation, and integrating features within the app.

Another challenge was **implementing location-based functionality while maintaining user privacy**. Because Happs relies on location awareness to show which friends are nearby on campus, we needed to ensure that location sharing only occurred within designated areas (such as campus). Designing this restriction required additional logic and testing to make sure users’ locations were not shared outside the intended zones.

Finally, **coordinating features** like event creation and user availability was technically challenging. We needed to design a system that allowed users to quickly create spontaneous activities (“happs”) while ensuring notifications were meaningful and not overwhelming. Balancing simplicity, usability, and functionality required multiple iterations during development.

## Accomplishments that we're proud of
We are especially proud of successfully developing Happs, an app designed to help university students coordinate spontaneous social activities on campus. 👯‍♂️ Our team created a system that allows users to easily see which friends are nearby, check their availability, and organise quick events such as food runs, study sessions, or sports activities. 🏃💨

A key achievement was implementing location-aware features with built-in privacy controls. 🔐 Location sharing is limited to predefined public locations like campus, ensuring that users are not sharing their location continuously. This design allowed us to balance the usefulness of location awareness with important privacy considerations.

We are also proud of building a simple and intuitive event creation system, allowing users to create “happs” quickly and invite friends or nearby students to join. Despite learning Flutter during the project, our team successfully delivered a working prototype that demonstrates how technology can make spontaneous social coordination easier for students.

## What we learned
During this project, our team gained hands-on experience with Flutter and Dart, going from little to no prior knowledge to delivering a fully working cross-platform prototype. We deepened our understanding of Firebase's ecosystem — including Firestore real-time streams, Firebase Auth, and Cloud Messaging — and learned how to architect a lightweight but scalable app under time pressure. Beyond the technical side, we also learned the importance of scoping features early and iterating quickly, which helped us stay focused and ship a cohesive product within the hackathon timeframe. 💡

## What's next for Happs
Looking ahead, we plan to continue developing Happs by expanding its functionality beyond campus. One of our goals is to allow users to create **pre-planned Happs at off-campus locations**📍, enabling activities such as concerts, festivals, or group outings. During these events, users could temporarily share their location with friends for the duration of the activity, maintaining the **privacy-focused design** 🔒 that Happs is built on.

We also aim to improve the schedule integration within the app by allowing users to **import their calendar data**. 📅 This would enable Happs to identify times when friends are mutually available and **provide AI-powered suggestions** for activities. Ultimately, our goal is to make it even easier for students to discover opportunities to connect and socialise.

See you at the next Happs. 🎉
