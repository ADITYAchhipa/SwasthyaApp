const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const twilio = require('twilio');
const Citizen = require('../models/Citizen');
const OtpSession = require('../models/OtpSession');
const Hospital = require('../models/Hospital');

// ─── Twilio Client Initialization ──────────────────────────────────────────────
let twilioClient;

const initTwilio = () => {
  if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) {
    try {
      twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
      console.log('📱 Twilio client initialized successfully.');
      if (process.env.TWILIO_VERIFY_SERVICE_SID) {
        console.log('   Using Twilio Verify Service:', process.env.TWILIO_VERIFY_SERVICE_SID);
      } else if (process.env.TWILIO_PHONE_NUMBER) {
        console.log('   Using Twilio Programmable SMS Phone Number:', process.env.TWILIO_PHONE_NUMBER);
      }
    } catch (e) {
      console.error('❌ Failed to initialize Twilio client:', e.message);
    }
  } else {
    console.log('📱 Twilio credentials missing in .env (TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN).');
    console.log('   SMS OTPs will be printed to server terminal for testing.');
  }
};
initTwilio();

// Helper: Format phone number into E.164 format (e.g. +919876543210 or +12345678900)
const formatE164 = (phone) => {
  if (!phone) return '';
  let cleaned = String(phone).trim();
  const digits = cleaned.replace(/\D/g, '');
  if (cleaned.startsWith('+')) {
    return `+${digits}`;
  }
  if (digits.length === 10) {
    return `+91${digits}`;
  }
  if (digits.length === 12 && digits.startsWith('91')) {
    return `+${digits}`;
  }
  return `+91${digits.slice(-10)}`;
};

// Helper: Generate 4-digit OTP for dev/programmable mode
const generateOtp = () => Math.floor(1000 + Math.random() * 9000).toString();

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
// Send SMS OTP to citizen's mobile number via Twilio
router.post('/send-otp', async (req, res) => {
  try {
    const { phone, mobileNumber, phoneNumber, email } = req.body;
    const rawPhone = phone || mobileNumber || phoneNumber || email;

    if (!rawPhone) {
      return res.status(400).json({ success: false, message: 'Mobile phone number is required' });
    }

    const formattedPhone = formatE164(rawPhone);
    const clean10Digit = formattedPhone.replace(/\D/g, '').slice(-10);

    if (!clean10Digit || clean10Digit.length < 10) {
      return res.status(400).json({ success: false, message: 'Please provide a valid 10-digit mobile number' });
    }

    let devOtp = null;
    const verifyServiceSid = process.env.TWILIO_VERIFY_SERVICE_SID;

    if (twilioClient && verifyServiceSid) {
      // Method A: Twilio Verify Service API (Recommended)
      try {
        await twilioClient.verify.v2
          .services(verifyServiceSid)
          .verifications.create({ to: formattedPhone, channel: 'sms' });
        console.log(`\n📱 [Twilio Verify] Sent SMS OTP to ${formattedPhone}\n`);
      } catch (twilioErr) {
        console.error('❌ Twilio Verify Service error:', twilioErr.message);
        // Fallback to local OTP generation if Twilio API call fails
        devOtp = generateOtp();
        const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
        await OtpSession.deleteMany({ phone: clean10Digit, purpose: 'citizen_login' });
        await OtpSession.create({ phone: clean10Digit, otp: devOtp, purpose: 'citizen_login', expiresAt });
        console.log(`\n📱 [Fallback Dev Log] SMS OTP for ${formattedPhone}: ${devOtp}\n`);
      }
    } else if (twilioClient && process.env.TWILIO_PHONE_NUMBER) {
      // Method B: Twilio Programmable SMS (via Phone Number)
      const otp = generateOtp();
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

      await OtpSession.deleteMany({ phone: clean10Digit, purpose: 'citizen_login' });
      await OtpSession.create({ phone: clean10Digit, otp, purpose: 'citizen_login', expiresAt });

      try {
        const msg = await twilioClient.messages.create({
          body: `Your SwasthyaTap verification OTP is ${otp}. It expires in 5 minutes.`,
          from: process.env.TWILIO_PHONE_NUMBER,
          to: formattedPhone,
        });
        console.log(`\n📱 [Twilio SMS] Sent OTP to ${formattedPhone} (SID: ${msg.sid})\n`);
      } catch (twilioErr) {
        console.error('❌ Twilio Programmable SMS error:', twilioErr.message);
        devOtp = otp;
        console.log(`\n📱 [Fallback Dev Log] SMS OTP for ${formattedPhone}: ${otp}\n`);
      }
    } else {
      // Dev mode without active Twilio credentials
      const otp = generateOtp();
      devOtp = otp;
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

      await OtpSession.deleteMany({ phone: clean10Digit, purpose: 'citizen_login' });
      await OtpSession.create({ phone: clean10Digit, otp, purpose: 'citizen_login', expiresAt });

      console.log(`\n📱 [Terminal Dev Mode] SMS OTP for ${formattedPhone} (+91-${clean10Digit}): ${otp}\n`);
    }

    const showDevOtp = devOtp || (process.env.NODE_ENV !== 'production' && process.env.SHOW_DEV_OTP === 'true');

    res.json({
      success: true,
      message: `OTP sent via SMS to ${formattedPhone}`,
      ...(showDevOtp && devOtp && { devOtp }),
    });
  } catch (err) {
    console.error('send-otp error:', err);
    res.status(500).json({ success: false, message: 'Failed to send OTP to mobile number' });
  }
});

// ─── POST /api/auth/verify-otp ───────────────────────────────────────────────
// Verify SMS OTP and login/register citizen
router.post('/verify-otp', async (req, res) => {
  try {
    const { phone, mobileNumber, phoneNumber, email, otp } = req.body;
    const rawPhone = phone || mobileNumber || phoneNumber || email;

    if (!rawPhone || !otp) {
      return res.status(400).json({ success: false, message: 'Mobile phone number and OTP are required' });
    }

    const formattedPhone = formatE164(rawPhone);
    const clean10Digit = formattedPhone.replace(/\D/g, '').slice(-10);
    let isOtpValid = false;

    const verifyServiceSid = process.env.TWILIO_VERIFY_SERVICE_SID;

    if (twilioClient && verifyServiceSid) {
      // Check via Twilio Verify API first
      try {
        const check = await twilioClient.verify.v2
          .services(verifyServiceSid)
          .verificationChecks.create({ to: formattedPhone, code: otp.toString() });

        if (check.status === 'approved') {
          isOtpValid = true;
        }
      } catch (e) {
        console.warn('Twilio Verify check failed, checking local database session...', e.message);
      }
    }

    // Fallback or Programmable SMS database session check
    if (!isOtpValid) {
      const session = await OtpSession.findOne({
        phone: clean10Digit,
        purpose: 'citizen_login',
        used: false,
        expiresAt: { $gt: new Date() },
      });

      if (session && session.otp === otp.toString()) {
        isOtpValid = true;
        session.used = true;
        await session.save();
      }
    }

    if (!isOtpValid) {
      return res.status(401).json({ success: false, message: 'Invalid or expired OTP' });
    }

    // Find or create citizen profile by mobile number
    let citizen = await Citizen.findOne({
      $or: [
        { phoneNumber: clean10Digit },
        { phoneNumber: formattedPhone },
        { phoneNumber: `+91${clean10Digit}` },
      ],
    });

    let isNewUser = false;

    if (!citizen) {
      isNewUser = true;
      let profileId = generateProfileId();
      while (await Citizen.findOne({ profileId })) {
        profileId = generateProfileId();
      }

      citizen = await Citizen.create({
        profileId,
        phoneNumber: clean10Digit,
        fullName: 'SwasthyaTap User',
        bloodGroup: 'Unknown',
        emergencyContacts: [],
        lifeCredits: 0,
      });
    }

    // Issue JWT token
    const token = jwt.sign(
      { citizenId: citizen.profileId, phoneNumber: citizen.phoneNumber },
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
    res.status(500).json({ success: false, message: 'Mobile OTP verification failed' });
  }
});

// ─── POST /api/auth/hospital/send-otp ────────────────────────────────────────
router.post('/hospital/send-otp', async (req, res) => {
  try {
    const { phone, hospitalId } = req.body;

    if (!phone || !hospitalId) {
      return res.status(400).json({ success: false, message: 'Phone number and Hospital ID required' });
    }

    const hospital = await Hospital.findOne({ hospitalId });
    if (!hospital) {
      return res.status(404).json({ success: false, message: 'Hospital ID not found in registry' });
    }

    const formattedPhone = formatE164(phone);
    const cleanPhone = formattedPhone.replace(/\D/g, '').slice(-10);

    await OtpSession.deleteMany({ phone: cleanPhone, purpose: 'hospital_login' });

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    await OtpSession.create({ phone: cleanPhone, otp, purpose: 'hospital_login', expiresAt });

    let devOtp = null;
    const verifyServiceSid = process.env.TWILIO_VERIFY_SERVICE_SID;

    if (twilioClient && verifyServiceSid) {
      try {
        await twilioClient.verify.v2.services(verifyServiceSid).verifications.create({ to: formattedPhone, channel: 'sms' });
      } catch (e) {
        devOtp = otp;
      }
    } else if (twilioClient && process.env.TWILIO_PHONE_NUMBER) {
      try {
        await twilioClient.messages.create({
          body: `Hospital Login OTP for ${hospital.name} is ${otp}. Valid for 5 minutes.`,
          from: process.env.TWILIO_PHONE_NUMBER,
          to: formattedPhone,
        });
      } catch (e) {
        devOtp = otp;
      }
    } else {
      devOtp = otp;
      console.log(`\n🏥 Hospital SMS OTP for ${hospital.name} (${formattedPhone}): ${otp}\n`);
    }

    const showDevOtp = devOtp || (process.env.NODE_ENV !== 'production' && process.env.SHOW_DEV_OTP === 'true');

    res.json({
      success: true,
      message: `OTP sent to mobile number for ${hospital.name}`,
      hospitalName: hospital.name,
      ...(showDevOtp && devOtp && { devOtp }),
    });
  } catch (err) {
    console.error('hospital send-otp error:', err);
    res.status(500).json({ success: false, message: 'Failed to send SMS OTP' });
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

    const authorizedStaff = hospital.authorizedPersonnel.find(
      (p) => p.personnelId === personnelId
    );
    if (!authorizedStaff) {
      return res.status(403).json({ success: false, message: 'Personnel ID not authorized for this hospital' });
    }

    const formattedPhone = formatE164(phone);
    const cleanPhone = formattedPhone.replace(/\D/g, '').slice(-10);
    let isOtpValid = false;

    const verifyServiceSid = process.env.TWILIO_VERIFY_SERVICE_SID;

    if (twilioClient && verifyServiceSid) {
      try {
        const check = await twilioClient.verify.v2
          .services(verifyServiceSid)
          .verificationChecks.create({ to: formattedPhone, code: otp.toString() });
        if (check.status === 'approved') {
          isOtpValid = true;
        }
      } catch (e) {
        console.warn('Twilio verify hospital check failed, falling back to local session', e.message);
      }
    }

    if (!isOtpValid) {
      const session = await OtpSession.findOne({
        phone: cleanPhone,
        purpose: 'hospital_login',
        used: false,
        expiresAt: { $gt: new Date() },
      });

      if (session && session.otp === otp.toString()) {
        isOtpValid = true;
        session.used = true;
        await session.save();
      }
    }

    if (!isOtpValid) {
      return res.status(401).json({ success: false, message: 'Invalid or expired OTP' });
    }

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
    receipts: c.receipts || [],
    prescriptions: c.prescriptions || [],
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
