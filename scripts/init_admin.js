const admin = require('firebase-admin');
const serviceAccount = require('../mobile-project-63d46-firebase-adminsdk.json');

// Initialize admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://mobile-project-63d46.firebaseio.com',
});

const db = admin.firestore();

async function initializeAdmin() {
  try {
    console.log('🔧 Initializing admin account...');
    
    // Check if admin already exists
    const adminSnapshot = await db.collection('users')
      .where('email', '==', 'admin@upm.edu.my')
      .get();
    
    if (!adminSnapshot.empty) {
      console.log('⚠️ Admin already exists');
      return;
    }
    
    // Create admin user data
    const adminData = {
      email: 'admin@upm.edu.my',
      displayName: 'System Administrator',
      userType: 'admin',
      role: 'System Administrator',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      permissions: [
        'manage_users',
        'manage_certificates',
        'manage_system',
        'view_analytics',
        'manage_ca',
        'approve_requests',
      ],
      department: 'IT Department',
      staffId: 'ADMIN001',
      profileComplete: true,
    };
    
    // Create admin user document
    await db.collection('users').doc('admin_user_id').set(adminData);
    console.log('✅ Admin user created in Firestore');
    
    // Mark system as initialized
    await db.collection('system_config').doc('adminInitialized').set({
      initialized: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      adminEmail: 'admin@upm.edu.my',
    });
    console.log('✅ System marked as initialized');
    
    console.log('\n📌 Admin account created successfully!');
    console.log('Email: admin@upm.edu.my');
    console.log('You can now login with Google Sign-In using this email.');
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit();
  }
}

// Run the initialization
initializeAdmin(); 