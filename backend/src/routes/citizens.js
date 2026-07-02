const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const Citizen = require('../models/Citizen');
const { authenticate } = require('../middleware/auth');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const storage = multer.memoryStorage();
const upload = multer({ storage: storage, limits: { fileSize: 10 * 1024 * 1024 } }); // 10MB limit

const uploadToCloudinary = (fileBuffer, originalName) => {
  return new Promise((resolve, reject) => {
    if (!process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
      console.warn("⚠️ Cloudinary credentials missing in .env. Falling back to mock URL.");
      return resolve({
        secure_url: "https://res.cloudinary.com/demo/image/upload/v1570530932/sample.jpg",
        public_id: "mock_report_" + Date.now(),
      });
    }

    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder: "swasthyatap_reports",
        resource_type: "auto",
        public_id: `report_${Date.now()}_${originalName.replace(/[^a-zA-Z0-9]/g, '_')}`,
      },
      (error, result) => {
        if (error) return reject(error);
        resolve(result);
      }
    );
    uploadStream.end(fileBuffer);
  });
};

// ─── Helper: Format citizen for response ─────────────────────────────────────
function formatCitizen(c) {
  return {
    id: c.profileId,
    fullName: c.fullName,
    phoneNumber: c.phoneNumber,
    bloodGroup: c.bloodGroup,
    age: c.age,
    address: c.address,
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

// ─── GET /api/citizens/:id ────────────────────────────────────────────────────
// Public read — used when a hospital NFC-scans a card
router.get('/:id', async (req, res) => {
  try {
    const citizen = await Citizen.findOne({ profileId: req.params.id });
    if (!citizen) {
      return res.status(404).json({ success: false, message: 'Citizen profile not found' });
    }
    res.json({ success: true, citizen: formatCitizen(citizen) });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ─── PUT /api/citizens/:id ────────────────────────────────────────────────────
// Update medical profile — requires auth
router.put('/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;

    // Only allow the owner to update their own profile
    if (req.user.citizenId !== id) {
      return res.status(403).json({ success: false, message: 'Unauthorized to update this profile' });
    }

    const allowedFields = [
      'fullName',
      'bloodGroup',
      'age',
      'address',
      'phoneNumber',
      'allergies',
      'medications',
      'chronicConditions',
      'specialInstructions',
      'isDnr',
      'emergencyContacts',
      'insuranceCompany',
      'insurancePolicyNumber',
      'isBloodDonor',
      'donorRadiusKm',
      'homeLat',
      'homeLng',
      'selectedLanguage',
    ];

    const updates = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    }

    // Sanitize phoneNumber to prevent sparse unique index conflict on empty values
    if (updates.phoneNumber !== undefined) {
      const cleanPhone = updates.phoneNumber.trim().replace(/\s+/g, '');
      if (cleanPhone === '') {
        updates.phoneNumber = undefined;
      } else {
        updates.phoneNumber = cleanPhone;
      }
    }

    const citizen = await Citizen.findOneAndUpdate(
      { profileId: id },
      { $set: updates },
      { new: true, runValidators: true }
    );

    if (!citizen) {
      return res.status(404).json({ success: false, message: 'Citizen not found' });
    }

    res.json({ success: true, citizen: formatCitizen(citizen) });
  } catch (err) {
    console.error('update citizen error:', err);
    res.status(500).json({ success: false, message: 'Update failed' });
  }
});

// ─── POST /api/citizens/:id/organ-pledge ─────────────────────────────────────
// Sign organ donation pledge — requires auth
router.post('/:id/organ-pledge', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { organs } = req.body;

    if (req.user.citizenId !== id) {
      return res.status(403).json({ success: false, message: 'Unauthorized' });
    }

    if (!organs || !Array.isArray(organs) || organs.length === 0) {
      return res.status(400).json({ success: false, message: 'At least one organ must be selected' });
    }

    const citizen = await Citizen.findOne({ profileId: id });
    if (!citizen) {
      return res.status(404).json({ success: false, message: 'Citizen not found' });
    }

    // Generate cryptographic hash (matching Flutter logic)
    const dateStr = new Date().toISOString().split('T')[0];
    const payload = `${citizen.profileId}|${citizen.fullName}|${dateStr}|${organs.join(',')}`;
    const signatureHash = crypto.createHash('sha256').update(payload).digest('hex');

    const pledge = {
      pledgeId: `NOTTO-${citizen.profileId.toUpperCase()}`,
      pledgedOrgans: organs,
      signedDate: dateStr,
      signatureHash,
      nottoVerified: true,
    };

    citizen.organPledge = pledge;
    await citizen.save();

    res.json({ success: true, organPledge: pledge, citizen: formatCitizen(citizen) });
  } catch (err) {
    console.error('organ-pledge error:', err);
    res.status(500).json({ success: false, message: 'Failed to register pledge' });
  }
});

// ─── POST /api/citizens/:id/verify-organ-consent ─────────────────────────────
// NOTTO consent verification — public
router.post('/:id/verify-organ-consent', async (req, res) => {
  try {
    const { signatureHash } = req.body;
    const citizen = await Citizen.findOne({
      profileId: req.params.id,
      'organPledge.signatureHash': signatureHash,
    });
    res.json({ success: true, verified: !!citizen });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Verification failed' });
  }
});

// ─── POST /api/citizens/:id/add-credits ──────────────────────────────────────
// Add life credits (called after blood donation acceptance)
router.post('/:id/add-credits', authenticate, async (req, res) => {
  try {
    const { credits } = req.body;
    const citizen = await Citizen.findOneAndUpdate(
      { profileId: req.params.id },
      { $inc: { lifeCredits: credits || 100 } },
      { new: true }
    );
    if (!citizen) return res.status(404).json({ success: false, message: 'Citizen not found' });
    res.json({ success: true, lifeCredits: citizen.lifeCredits });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to add credits' });
  }
});

module.exports = router;
