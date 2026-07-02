const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const Citizen = require('../models/Citizen');
const OtpSession = require('../models/OtpSession');
const Hospital = require('../models/Hospital');

// Configure nodemailer transporter (will be initialized dynamically)
let transporter;

const initTransporter = async () => {
  if (process.env.SMTP_USER && process.env.SMTP_HOST) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    console.log('📬 Nodemailer configured using SMTP credentials from environment.');
  } else {
    try {
      console.log('📬 SMTP credentials missing in environment. Creating free test account on Ethereal Mail...');
      const testAccount = await nodemailer.createTestAccount();
      transporter = nodemailer.createTransport({
        host: testAccount.smtp.host,
        port: testAccount.smtp.port,
        secure: testAccount.smtp.secure,
        auth: {
          user: testAccount.user,
          pass: testAccount.pass,
        },
      });
      console.log(`📬 Ethereal test SMTP account created!`);
      console.log(`   User: ${testAccount.user}`);
      console.log(`   Pass: ${testAccount.pass}`);
    } catch (e) {
      console.error('❌ Failed to create Ethereal SMTP test account, fallback to console log only:', e.message);
    }
  }
};
initTransporter();

// Helper: send Email OTP
const sendEmailOtp = async (email, otp) => {
  let senderEmail = 'no-reply@swasthyatap.in';
  if (process.env.SMTP_USER && process.env.SMTP_HOST) {
    if (process.env.SMTP_USER === 'resend') {
      senderEmail = 'onboarding@resend.dev';
    } else {
      senderEmail = process.env.SMTP_USER;
    }
  } else if (transporter && transporter.options && transporter.options.auth) {
    senderEmail = transporter.options.auth.user;
  }

  const mailOptions = {
    from: `"SwasthyaTap" <${senderEmail}>`,
    to: email,
    subject: 'SwasthyaTap Verification OTP',
    text: `Your OTP for SwasthyaTap citizen login/registration is ${otp}. It will expire in 5 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
        <h2 style="color: #0f766e; text-align: center;">SwasthyaTap Verification</h2>
        <p>Hello,</p>
        <p>Use the following 4-digit OTP to complete your registration or login to SwasthyaTap:</p>
        <div style="background-color: #f1f5f9; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #0f766e; border-radius: 6px; margin: 20px 0;">
          ${otp}
        </div>
        <p style="font-size: 12px; color: #64748b;">This OTP will expire in 5 minutes. If you did not request this, you can safely ignore this email.</p>
      </div>
    `,
  };

  if (!transporter) {
    console.log(`\n📧 [Transporter Offline] Logged Email OTP for ${email}: ${otp} (expires in 5 minutes)\n`);
    return false;
  }

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`\n📧 Email OTP sent to ${email} (expires in 5 minutes)`);
    // If it's Ethereal, log preview link
    const previewUrl = nodemailer.getTestMessageUrl(info);
    if (previewUrl) {
      console.log(`📬 Ethereal Email Preview URL: ${previewUrl}\n`);
    } else {
      console.log(`📬 Mail Sent ID: ${info.messageId}\n`);
    }
    return true;
  } catch (err) {
    console.error('❌ Failed to send email via SMTP:', err.message);
    console.log(`\n📧 [Fallback Log] Email OTP for ${email}: ${otp} (expires in 5 minutes)\n`);
    return false;
  }
};

// Helper: Generate 4-digit OTP
const generateOtp = () => Math.floor(1000 + Math.random() * 9000).toString();

// Helper: Validate email format
const validateEmail = (email) => {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(String(email).toLowerCase());
};

// Helper: Generate a unique 6-char profile ID
const generateProfileId = () => {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let id = '';
  for (let i = 0; i < 6; i++) {
    id += chars[Math.floor(Math.random() * chars.length)];
  }
  return id;
};

// ─── POST /api/auth/send-otp ──────────────────────────────────────────────────
// Send OTP to citizen's email address
router.post('/send-otp', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !validateEmail(email)) {
      return res.status(400).json({ success: false, message: 'Valid email address required' });
    }

    const cleanEmail = email.trim().toLowerCase();

    // Delete any existing unused OTP for this email
    await OtpSession.deleteMany({ email: cleanEmail, purpose: 'citizen_login' });

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    await OtpSession.create({ email: cleanEmail, otp, purpose: 'citizen_login', expiresAt });

    // Send email (actual or mock console log)
    await sendEmailOtp(cleanEmail, otp);

    const isEthereal = transporter && transporter.options && transporter.options.host && transporter.options.host.includes('ethereal');
    const hasRealSmtp = process.env.SMTP_USER && process.env.SMTP_HOST && !isEthereal;
    const showDevOtp = process.env.NODE_ENV !== 'production' && (!hasRealSmtp || process.env.SHOW_DEV_OTP === 'true');

    res.json({
      success: true,
      message: `OTP sent to ${cleanEmail}`,
      ...(showDevOtp && { devOtp: otp }),
    });
  } catch (err) {
    console.error('send-otp error:', err);
    res.status(500).json({ success: false, message: 'Failed to send OTP' });
  }
});

// ─── POST /api/auth/verify-otp ───────────────────────────────────────────────
// Verify OTP and login/register citizen
router.post('/verify-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: 'Email and OTP required' });
    }

    const cleanEmail = email.trim().toLowerCase();

    // Find valid OTP session
    const session = await OtpSession.findOne({
      email: cleanEmail,
      purpose: 'citizen_login',
      used: false,
      expiresAt: { $gt: new Date() },
    });

    if (!session) {
      return res.status(401).json({ success: false, message: 'OTP expired or invalid. Please request a new one.' });
    }

    if (session.otp !== otp.toString()) {
      return res.status(401).json({ success: false, message: 'Incorrect OTP' });
    }

    // Mark OTP as used
    session.used = true;
    await session.save();

    // Find or create citizen
    let citizen = await Citizen.findOne({ email: cleanEmail });
    let isNewUser = false;

    if (!citizen) {
      // New user — create a minimal profile
      isNewUser = true;
      let profileId = generateProfileId();
      // Ensure profileId is unique
      while (await Citizen.findOne({ profileId })) {
        profileId = generateProfileId();
      }

      citizen = await Citizen.create({
        profileId,
        email: cleanEmail,
        fullName: 'SwasthyaTap User',
        bloodGroup: 'Unknown',
        emergencyContacts: [],
        lifeCredits: 0,
      });
    }

    // Issue JWT token
    const token = jwt.sign(
      { citizenId: citizen.profileId, email: cleanEmail },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      isNewUser,
      token,
      citizen: formatCitizen(citizen),
    });
  } catch (err) {
    console.error('verify-otp error:', err);
    res.status(500).json({ success: false, message: 'Verification failed' });
  }
});

// ─── POST /api/auth/hospital/send-otp ────────────────────────────────────────
router.post('/hospital/send-otp', async (req, res) => {
  try {
    const { phone, hospitalId } = req.body;

    if (!phone || !hospitalId) {
      return res.status(400).json({ success: false, message: 'Phone and Hospital ID required' });
    }

    // Verify this hospital exists
    const hospital = await Hospital.findOne({ hospitalId });
    if (!hospital) {
      return res.status(404).json({ success: false, message: 'Hospital ID not found in registry' });
    }

    const cleanPhone = phone.replace(/\D/g, '').slice(-10);

    await OtpSession.deleteMany({ phone: cleanPhone, purpose: 'hospital_login' });

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    await OtpSession.create({ phone: cleanPhone, otp, purpose: 'hospital_login', expiresAt });

    console.log(`\n🏥 Hospital OTP for ${hospital.name} (+91-${cleanPhone}): ${otp}\n`);

    const isEthereal = transporter && transporter.options && transporter.options.host && transporter.options.host.includes('ethereal');
    const hasRealSmtp = process.env.SMTP_USER && process.env.SMTP_HOST && !isEthereal;
    const showDevOtp = process.env.NODE_ENV !== 'production' && (!hasRealSmtp || process.env.SHOW_DEV_OTP === 'true');

    res.json({
      success: true,
      message: `OTP sent to registered number for ${hospital.name}`,
      hospitalName: hospital.name,
      ...(showDevOtp && { devOtp: otp }),
    });
  } catch (err) {
    console.error('hospital send-otp error:', err);
    res.status(500).json({ success: false, message: 'Failed to send OTP' });
  }
});

// ─── POST /api/auth/hospital/verify ──────────────────────────────────────────
router.post('/hospital/verify', async (req, res) => {
  try {
    const { hospitalId, personnelId, phone, otp } = req.body;

    if (!hospitalId || !personnelId || !phone || !otp) {
      return res.status(400).json({ success: false, message: 'All fields are required' });
    }

    const hospital = await Hospital.findOne({ hospitalId });
    if (!hospital) {
      return res.status(404).json({ success: false, message: 'Hospital not found' });
    }

    // Check personnel ID is authorized
    const authorizedStaff = hospital.authorizedPersonnel.find(
      (p) => p.personnelId === personnelId
    );
    if (!authorizedStaff) {
      return res.status(403).json({ success: false, message: 'Personnel ID not authorized for this hospital' });
    }

    // Verify OTP
    const cleanPhone = phone.replace(/\D/g, '').slice(-10);
    const session = await OtpSession.findOne({
      phone: cleanPhone,
      purpose: 'hospital_login',
      used: false,
      expiresAt: { $gt: new Date() },
    });

    if (!session || session.otp !== otp.toString()) {
      return res.status(401).json({ success: false, message: 'Invalid or expired OTP' });
    }

    session.used = true;
    await session.save();

    // Issue hospital JWT
    const token = jwt.sign(
      { hospitalId: hospital.hospitalId, personnelId, hospitalName: hospital.name },
      process.env.JWT_SECRET,
      { expiresIn: '12h' }
    );

    res.json({
      success: true,
      token,
      hospital: {
        hospitalId: hospital.hospitalId,
        name: hospital.name,
        address: hospital.address,
        city: hospital.city,
        lat: hospital.lat,
        lng: hospital.lng,
        specialties: hospital.specialties,
      },
      personnel: authorizedStaff,
    });
  } catch (err) {
    console.error('hospital verify error:', err);
    res.status(500).json({ success: false, message: 'Hospital verification failed' });
  }
});

// ─── Helper: Format citizen for API response ──────────────────────────────────
function formatCitizen(c) {
  return {
    id: c.profileId,
    fullName: c.fullName,
    phoneNumber: c.phoneNumber,
    email: c.email,
    bloodGroup: c.bloodGroup,
    allergies: c.allergies,
    medications: c.medications,
    chronicConditions: c.chronicConditions,
    specialInstructions: c.specialInstructions,
    isDnr: c.isDnr,
    emergencyContacts: c.emergencyContacts,
    organPledge: c.organPledge,
    insuranceCompany: c.insuranceCompany,
    insurancePolicyNumber: c.insurancePolicyNumber,
    medicalReports: c.medicalReports || [],
    isBloodDonor: c.isBloodDonor,
    donorRadiusKm: c.donorRadiusKm,
    homeLat: c.homeLat,
    homeLng: c.homeLng,
    lifeCredits: c.lifeCredits,
    selectedLanguage: c.selectedLanguage,
    profileCompleteness: c.calculateCompleteness(),
    createdAt: c.createdAt,
  };
}

module.exports = router;
module.exports.formatCitizen = formatCitizen;
