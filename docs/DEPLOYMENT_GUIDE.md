# Digital Certificate Repository - Deployment Guide

## Prerequisites

1. **Development Environment**
   - Flutter SDK 3.24.0 or higher
   - Dart SDK 3.1.0 or higher
   - Node.js 18 or higher
   - Firebase CLI (`npm install -g firebase-tools`)
   - Git

2. **Firebase Project**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable the following services:
     - Authentication (Google Sign-In)
     - Cloud Firestore
     - Cloud Storage
     - Cloud Functions (Blaze plan required)
     - Cloud Messaging

3. **Stripe Account** (for donation feature)
   - Create a Stripe account at [stripe.com](https://stripe.com)
   - Get your publishable and secret keys

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/digital-certificate-repository.git
cd digital-certificate-repository
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

```bash
# Login to Firebase
firebase login

# Initialize FlutterFire
flutterfire configure

# Select your Firebase project and platforms
```

### 4. Set Environment Variables

Create a `.env` file in the root directory:

```env
STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key
STRIPE_SECRET_KEY=sk_test_your_secret_key
VAPID_KEY=your_firebase_vapid_key
```

### 5. Deploy Firebase Security Rules

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage:rules
```

### 6. Setup Firebase Functions

```bash
cd functions
npm install

# Set Stripe configuration
firebase functions:config:set stripe.secret_key="sk_test_your_secret_key"
firebase functions:config:set stripe.webhook_secret="whsec_your_webhook_secret"

# Deploy functions
firebase deploy --only functions
```

### 7. Configure Stripe Webhook

1. Go to Stripe Dashboard → Webhooks
2. Add endpoint: `https://your-region-your-project.cloudfunctions.net/stripeWebhook`
3. Select events: `payment_intent.succeeded`, `payment_intent.payment_failed`
4. Copy the webhook secret and update Firebase Functions config

## Building and Deployment

### Android

1. **Generate keystore** (first time only):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Configure signing** in `android/key.properties`:
   ```properties
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=upload
   storeFile=/Users/username/upload-keystore.jks
   ```

3. **Build APK**:
   ```bash
   flutter build apk --release
   ```

4. **Build App Bundle** (for Play Store):
   ```bash
   flutter build appbundle --release
   ```

### iOS

1. **Open Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Configure signing**:
   - Select Runner project
   - Select your team
   - Set bundle identifier

3. **Build**:
   ```bash
   flutter build ios --release
   ```

### Web

1. **Build**:
   ```bash
   flutter build web --release
   ```

2. **Deploy to Firebase Hosting**:
   ```bash
   firebase deploy --only hosting
   ```

## Production Checklist

### Security

- [ ] Update Firebase security rules for production
- [ ] Enable App Check for additional security
- [ ] Configure domain restrictions for Google Sign-In
- [ ] Set up proper CORS rules
- [ ] Enable HTTPS everywhere
- [ ] Implement rate limiting

### Performance

- [ ] Enable Firebase Performance Monitoring
- [ ] Configure CDN for static assets
- [ ] Optimize images and assets
- [ ] Enable gzip compression
- [ ] Implement lazy loading

### Monitoring

- [ ] Set up Firebase Crashlytics
- [ ] Configure Google Analytics
- [ ] Set up error reporting
- [ ] Create monitoring dashboards
- [ ] Set up alerts for critical events

### Backup

- [ ] Configure automated Firestore backups
- [ ] Set up Storage bucket replication
- [ ] Document recovery procedures
- [ ] Test restore procedures

## Environment-Specific Configuration

### Development

```dart
// lib/core/config/app_config.dart
static const bool isProduction = false;
static const String apiBaseUrl = 'http://localhost:5001/mobile-project-63d46/us-central1';
```

### Production

```dart
// lib/core/config/app_config.dart
static const bool isProduction = true;
static const String apiBaseUrl = 'https://us-central1-mobile-project-63d46.cloudfunctions.net';
```

## CI/CD with GitHub Actions

The project includes GitHub Actions workflow for:
- Automated testing
- Code quality checks
- Multi-platform builds
- Deployment to Firebase

To enable:
1. Add secrets to GitHub repository:
   - `FIREBASE_SERVICE_ACCOUNT`: Service account JSON
   - `STRIPE_PUBLISHABLE_KEY`: Stripe publishable key
   - `STRIPE_SECRET_KEY`: Stripe secret key

2. Push to main branch to trigger deployment

## Troubleshooting

### Common Issues

1. **Build failures**:
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install
   ```

2. **Firebase connection issues**:
   - Check Firebase project configuration
   - Verify API keys in `firebase_options.dart`
   - Check network connectivity

3. **Stripe integration issues**:
   - Verify API keys
   - Check webhook configuration
   - Review Stripe logs

### Debug Commands

```bash
# Check Flutter environment
flutter doctor -v

# Firebase emulator
firebase emulators:start

# View function logs
firebase functions:log

# Test specific function
firebase functions:shell
```

## Maintenance

### Regular Tasks

- **Weekly**:
  - Review error logs
  - Check performance metrics
  - Monitor storage usage

- **Monthly**:
  - Update dependencies
  - Review security rules
  - Audit user permissions
  - Clean up temporary files

- **Quarterly**:
  - Security audit
  - Performance optimization
  - Backup restoration test
  - Update documentation

## Support

For deployment support:
- Email: support@digitalcertrepo.upm.edu.my
- Documentation: [Project Wiki](https://github.com/yourusername/digital-certificate-repository/wiki)
- Issues: [GitHub Issues](https://github.com/yourusername/digital-certificate-repository/issues)

---

**Note**: Always test in a staging environment before deploying to production! 