# Firebase Complete Configuration Guide

## 🔥 Firebase Configuration Checklist

### ✅ 1. Firebase Project Basic Information
- **Project ID**: `mobile-project-63d46`
- **Project Name**: Digital Certificate Repository
- **Default Region**: `us-central1`

### ✅ 2. Configured Firebase Services

#### 2.1 Firebase Authentication ✅
- **Google Sign-In**: Enabled
- **Supported Domains**: @upm.edu.my
- **Configuration Files**: 
  - `lib/firebase_options.dart` ✅
  - `android/app/google-services.json` ✅

#### 2.2 Cloud Firestore ✅
- **Database Mode**: Production
- **Security Rules**: `firestore.rules` ✅
- **Index Configuration**: `firestore.indexes.json` ✅

#### 2.3 Firebase Storage ✅
- **Security Rules**: `storage.rules` ✅
- **File Size Limit**: 10MB
- **Supported File Types**:
  - Images (image/*)
  - PDF Documents
  - Excel Files
  - CSV Files

#### 2.4 Firebase Cloud Functions ✅
- **Configuration File**: `functions/package.json` ✅
- **Main File**: `functions/index.js` ✅
- **Function List**:
  - `createPaymentIntent` - Stripe Payment Processing
  - `stripeWebhook` - Stripe Webhook Handler
  - `sendCertificateEmail` - Certificate Notifications
  - `onUserRoleUpdate` - User Role Updates
  - `cleanupTempFiles` - Temporary File Cleanup
  - `exportUserData` - User Data Export

#### 2.5 Firebase Cloud Messaging ✅
- **Initialization**: Configured in `main.dart`
- **Notification Service**: `lib/core/services/notification_service.dart`

### ✅ 3. Environment Configuration

#### 3.1 Create `.env` File
Create a `.env` file in the project root directory and add the following:

```env
# Firebase Configuration
FIREBASE_PROJECT_ID=mobile-project-63d46

# Stripe Configuration (Required - for donation feature)
STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_PUBLISHABLE_KEY_HERE
STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY_HERE

# Firebase Web Push Notifications (Optional)
VAPID_KEY=YOUR_VAPID_KEY_HERE

# Firebase Functions Configuration
FUNCTIONS_REGION=us-central1

# Environment
NODE_ENV=development
```

#### 3.2 Firebase Functions Environment Variables
```bash
# Set Stripe Keys
firebase functions:config:set stripe.secret_key="sk_test_YOUR_SECRET_KEY"
firebase functions:config:set stripe.webhook_secret="whsec_YOUR_WEBHOOK_SECRET"
```

### ✅ 4. Deployment Steps

#### 4.1 Install Dependencies
```bash
# Flutter Dependencies
flutter pub get

# Firebase Functions Dependencies
cd functions
npm install
cd ..
```

#### 4.2 Deploy Firebase Rules
```bash
# Deploy Firestore Rules
firebase deploy --only firestore:rules

# Deploy Storage Rules  
firebase deploy --only storage:rules

# Deploy Firestore Indexes
firebase deploy --only firestore:indexes
```

#### 4.3 Deploy Firebase Functions
```bash
firebase deploy --only functions
```

#### 4.4 Deploy to Firebase Hosting (Web Version)
```bash
# Build Web Version
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### ✅ 5. Database Collection Structure

#### 5.1 Main Collections
- **users** - User Information
- **certificates** - Certificate Data
- **documents** - Document Data
- **certificate_requests** - Certificate Requests
- **notifications** - Notification Information
- **donations** - Donation Records
- **system_config** - System Configuration

#### 5.2 Initial Data
The system will automatically create:
- Default admin account (admin@upm.edu.my)
- System configuration documents
- Necessary counters

### ✅ 6. Security Configuration

#### 6.1 Firestore Security Rules Features
- Role-Based Access Control (RBAC)
- User Type Validation (admin, ca, user)
- Document-level Permission Control
- Write Operation Validation

#### 6.2 Storage Security Rules Features
- File Type Validation
- File Size Limits (10MB)
- User-based Access Control
- Public/Private File Separation

### ✅ 7. Testing Configuration

#### 7.1 Local Testing
```bash
# Start Firebase Emulators
firebase emulators:start

# Run Flutter App (with emulators)
flutter run
```

#### 7.2 Production Environment Testing
1. Login with test account
2. Verify all features work properly
3. Check Firebase Console logs

### ✅ 8. Monitoring and Maintenance

#### 8.1 Firebase Console Monitoring
- **Authentication**: View user login status
- **Firestore**: Monitor database usage
- **Storage**: Check storage usage
- **Functions**: Check function execution logs

#### 8.2 Regular Maintenance Tasks
- Clean temporary files (auto-executed)
- Backup important data
- Update security rules
- Review user permissions

### ✅ 9. Troubleshooting

#### 9.1 Common Issues
1. **Login Failed**: Check Google Sign-In configuration
2. **Permission Error**: Verify Firestore rules
3. **File Upload Failed**: Check Storage rules and quotas
4. **Functions Error**: View Functions logs

#### 9.2 Debug Commands
```bash
# View Functions Logs
firebase functions:log

# Check Deployment Status
firebase list

# Verify Project Configuration
firebase projects:list
```

### ✅ 10. Important Reminders

1. **Before Production Deployment**:
   - Update all API keys
   - Enable App Check
   - Configure backup strategy
   - Set up monitoring alerts

2. **Security Best Practices**:
   - Regularly update dependencies
   - Review security rules
   - Monitor abnormal activities
   - Protect sensitive configurations

3. **Performance Optimization**:
   - Enable CDN
   - Optimize image resources
   - Use caching strategies
   - Monitor performance metrics

## 🎉 Configuration Complete!

All Firebase services are properly configured and ready. The system can run all features normally:
- ✅ User Authentication
- ✅ Data Storage
- ✅ File Management
- ✅ Real-time Notifications
- ✅ Payment Processing
- ✅ Cloud Functions

**Next Step**: Follow the deployment steps to publish the app to production! 