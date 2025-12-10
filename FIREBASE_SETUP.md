# Firebase Setup Guide for OpenEar (No CLI Required)

## Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com
2. Click **Add project**
3. Enter project name (e.g., "openear-app")
4. Click **Continue** and follow the setup wizard
5. Click **Create project**

## Step 2: Register Your Web App
1. In your Firebase project dashboard, click the **Web icon** (</>)
2. Enter app nickname (e.g., "OpenEar Web")
3. **Check** "Also set up Firebase Hosting" (optional)
4. Click **Register app**
5. **IMPORTANT**: Copy the Firebase configuration code that appears

## Step 3: Get Your Firebase Configuration
You'll see something like this:
```javascript
const firebaseConfig = {
  apiKey: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abcdef123456"
};
```

## Step 4: Update main.dart
Open `lib/main.dart` and replace the placeholder values with your actual config:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: 'YOUR_ACTUAL_API_KEY',           // from firebaseConfig
    appId: 'YOUR_ACTUAL_APP_ID',             // from firebaseConfig
    messagingSenderId: 'YOUR_ACTUAL_SENDER_ID', // from firebaseConfig
    projectId: 'YOUR_ACTUAL_PROJECT_ID',     // from firebaseConfig
    authDomain: 'your-project.firebaseapp.com',
    storageBucket: 'your-project.appspot.com',
  ),
);
```

## Step 5: Enable Email/Password Authentication
1. In Firebase Console, go to **Build** → **Authentication**
2. Click **Get started**
3. Click **Sign-in method** tab
4. Click **Email/Password**
5. Toggle **Enable** to ON
6. Click **Save**

## Step 6: Enable Firestore Database
1. In Firebase Console, go to **Build** → **Firestore Database**
2. Click **Create database**
3. Select **Start in test mode** (for development)
4. Choose a location closest to you
5. Click **Enable**

## Step 7: Update Firestore Security Rules (Important!)
1. In Firestore Database, go to **Rules** tab
2. Replace the rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read/write only their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

3. Click **Publish**

## Step 8: Run Your App
```powershell
cd C:\OpenEar\SE-OpenEar
flutter run -d chrome
```

## Troubleshooting

### Error: "Firebase: Error (auth/invalid-api-key)"
- Double-check your `apiKey` in `main.dart` matches exactly from Firebase Console
- Make sure there are no extra spaces

### Error: "Firebase: Error (auth/operation-not-allowed)"
- Go to Firebase Console → Authentication → Sign-in method
- Make sure Email/Password is **Enabled**

### Error: "Permission denied" in Firestore
- Check your Firestore Rules
- For testing, you can use this (less secure):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Testing Your Setup

1. **Sign Up**: Create a new account with username, email, and password
2. **Check Firebase Console**:
   - Go to **Authentication** → **Users** tab
   - You should see your new user listed
3. **Check Firestore**:
   - Go to **Firestore Database** → **Data** tab
   - You should see a `users` collection with your user document

## What's Working Now

✅ User registration (Sign Up)
✅ User login with email/password
✅ Username stored in Firestore
✅ Password hashing (handled by Firebase)
✅ Session management
✅ Error handling for duplicate emails, weak passwords, etc.
✅ Loading indicators

## Security Features

- Passwords are automatically encrypted by Firebase
- Authentication tokens are managed securely
- User data is protected by Firestore security rules
- HTTPS encryption for all data transfer

## Next Steps (Optional)

- Set up password reset functionality (already implemented in `auth_service.dart`)
- Add email verification
- Implement social login (Google, Facebook, etc.)
- Configure production security rules

