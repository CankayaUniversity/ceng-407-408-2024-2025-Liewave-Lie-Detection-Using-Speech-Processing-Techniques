# ceng-407-408-2024-2025-Liewave-Lie-Detection-Using-Speech-Processing-Techniques

# LieWave: Lie Detection Using Speech Processing Techniques

## Project Description
**LieWave** is a mobile app that uses advanced machine learning models to detect lies by analyzing speech patterns. It processes audio inputs to identify subtle cues in tone, pace, and linguistic features, providing real-time insights with a lie probability score.

---

## Team Members

| Name                 | Student Number      |
|----------------------|---------------------|
| [Onur Güven](https://github.com/OnurGuveen)         | 201611028 |
| [Eray Yıkar](https://github.com/Erykr1)   | 202011074 |
| [Berkay Üğe](https://github.com/berkayugeofficial)   | 202011055 |
| [Çağrı Başaran](https://github.com/cagribasaran)   | 202011015 |
| [Melih Taşkın](https://github.com/melihoverflow5) | 202111070 |

---

## Advisor
Prof. Dr. Hayri Sever

---

## Installation Guide

### 1. Clone the Repository  
```bash
git clone https://github.com/your-repo/ceng-407-408-2024-2025-Liewave-Lie-Detection-Using-Speech-Processing-Techniques.git
cd ceng-407-408-2024-2025-Liewave-Lie-Detection-Using-Speech-Processing-Techniques
```
## 2. Setup the Flask API Backend

### 2.1 Download Model Files

- Download the pre-trained machine learning model files from the following link:  
  [Google Drive - LieWave Model Files](https://drive.google.com/drive/folders/1vGualvMVq3KTJ9maXa6oeCHwYVg1qCqT?usp=sharing)

- Place the entire **`model`** folder inside the `liewave-API` directory in your cloned repository.

---

### 2.2 Environment Variables

Create a `.env` file inside the `liewave-API` directory. This file will contain configuration values required by the Flask backend.

You need to set the following variables in the `.env` file:

- **FLASK_APP**  
  Specifies the entry point script for Flask to run your application. Set to `app.py`.

- **FLASK_ENV**  
  Defines the environment mode for Flask. Use `development` for debugging purposes.

- **FIREBASE_CREDENTIALS_PATH**  
  The path to your Firebase Admin SDK JSON credentials file, which enables secure server-side access to Firebase services. You must download this JSON file from your Firebase project console and place it inside the API folder.

- **STORAGE_BUCKET**  
  Your Firebase Storage bucket URL, which is where audio recordings and other files will be uploaded.

- **MODEL_PATH**  
  Relative path to the folder containing your trained ML models. Should be set to `model` if you placed the model folder as instructed.

- **FIREBASE_DATABASE_ID**  
  The Firestore database identifier for your Firebase project. Usually `default` unless configured otherwise.

- **FFMPEG_PATH**  
  The full system path to the `ffmpeg.exe` executable, used for audio processing tasks. You must install FFmpeg on your machine and specify its path here.

---

### 2.3 Firebase Setup

Make sure your Firebase project is configured with the following services:

- **Firebase Storage:** For storing audio recordings.  
- **Firestore Database:** For storing prediction metadata such as user ID, timestamp, prediction, and confidence.  
- **Firebase Authentication:** For secure user authentication, especially Google Sign-In.

---

### 2.4 Install Python Dependencies

Before running the Flask API, install the required Python packages using:

```bash
pip install -r requirements.txt
```

### 2.5 Running the Flask API
After completing setup, navigate to the liewave-API directory and start the Flask API by running:

```bash
flask run
```

By default, the API will serve on http://localhost:5000 unless configured otherwise.

## 3. Setup the Flutter Mobile App

### 3.1 Firebase Configuration

Follow Firebase's official Flutter integration guide to set up Firebase in your Flutter project, including adding the necessary config files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS).

---

### 3.2 Environment Variables for Flutter

Create a `.env` file in the root directory of the Flutter project containing:

- **API_URL**  
  The base URL of the Flask API endpoint for prediction requests. This should include the IP address and port where your Flask API is running, for example:

```ini
API_URL=http://192.168.2.206:5000/predict
```

Make sure this URL is reachable from the device running the Flutter app.

3.3 Install Dependencies  
From your Flutter project root, run the following commands to refresh dependencies and clean build cache:

```bash
flutter pub clean
flutter pub get
```

### 3.4 Running the Flutter App
Connect your device or start an emulator, then run:

```bash
flutter run
```

## Important Notes and Requirements

- **Internet Access:** Both backend and mobile app require internet connectivity to communicate with Firebase services and the Flask API.

- **Microphone Permission:** The app requests microphone permission at runtime for recording audio. Ensure to grant this permission.

- **Audio Format:** The system records audio in AAC format and uploads it to Firebase Storage.

- **FFmpeg Installation:** For the backend audio processing, FFmpeg must be installed and the path correctly set in the `.env` file. FFmpeg is critical for audio file handling and preprocessing.

- **Firebase Admin Credentials:** Download from Firebase Console under Project Settings > Service Accounts. This file enables the backend to interact with Firebase securely.

- **IP Address:** If testing on a local network, ensure that your mobile device can access the Flask API server's IP address and port.

## Troubleshooting Tips

| Problem                 | Possible Cause                  | Suggested Solution                               |
|-------------------------|--------------------------------|-------------------------------------------------|
| App cannot access microphone | Permission denied            | Check device settings and allow microphone access |
| API requests fail       | Incorrect API URL or network issue | Verify `API_URL` in Flutter `.env` and network connection |
| Audio not uploading     | Firebase Storage misconfiguration | Check Firebase Storage rules and credentials     |
| Model predictions missing | API or model errors           | Check Flask API logs and ensure model is loaded correctly |
| Flutter build errors    | Dependency or configuration issues | Run `flutter clean` and `flutter pub get` again  |

## Additional Resources

- [Flutter Firebase Setup](https://firebase.flutter.dev/docs/overview/)
- [FFmpeg Official Download](https://ffmpeg.org/download.html)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Flask Documentation](https://flask.palletsprojects.com/en/latest/)
