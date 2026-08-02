const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const Citizen = require('../models/Citizen');
const NfcCard = require('../models/NfcCard');
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

// ─── GET /api/citizens/:id ────────────────────────────────────────────────────
// Public read — used when a hospital NFC-scans a card
router.get('/:id', async (req, res) => {
  try {
    let citizen = await Citizen.findOne({ profileId: req.params.id });

    // If not found by profileId and id is a 64-character hash:
    if (!citizen && req.params.id && req.params.id.length === 64) {
      // 1. Look up by NfcCard rawToken
      const card = await NfcCard.findOne({ rawToken: req.params.id });
      if (card) {
        citizen = await Citizen.findById(card.patientId);
      }

      // 2. If still not found, check if it's the SHA-256 fallback hash of a profileId
      if (!citizen) {
        const citizens = await Citizen.find({});
        citizen = citizens.find(
          c => crypto.createHash('sha256').update(c.profileId).digest('hex') === req.params.id
        );
      }
    }

    if (!citizen) {
      return res.status(404).json({ success: false, message: 'Citizen profile not found' });
    }
    res.json({ success: true, citizen: formatCitizen(citizen) });
  } catch (err) {
    console.error('Fetch citizen error:', err);
    res.status(500).json({ success: false, message: 'Server error', error: err.message, stack: err.stack });
  }
});

// ─── PUT /api/citizens/:id ────────────────────────────────────────────────────
// Update medical profile — requires auth
router.put('/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;

    // Allow either the citizen themselves or authenticated hospital personnel
    if (req.user.citizenId !== id && !req.user.hospitalId) {
      return res.status(403).json({ success: false, message: 'Unauthorized to update this profile' });
    }

    let allowedFields = [
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

    if (req.user.hospitalId && req.user.citizenId !== id) {
      allowedFields = [
        'bloodGroup',
        'allergies',
        'medications',
        'chronicConditions',
        'specialInstructions',
        'isDnr',
      ];
    }

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


// ─── GET /api/citizens/:id/nfc-token ─────────────────────────────────────────
// Hospital-authenticated: fetch (or generate) the NFC write URL for a patient
router.get('/:id/nfc-token', authenticate, async (req, res) => {
  try {
    // Allow either hospital personnel OR the citizen themselves
    if (!req.user.hospitalId && req.user.citizenId !== req.params.id) {
      return res.status(403).json({ success: false, message: 'Unauthorized to request card tokens' });
    }

    const citizen = await Citizen.findOne({ profileId: req.params.id });
    if (!citizen) {
      return res.status(404).json({ success: false, message: 'Patient with this SwasthyaTap ID not found' });
    }

    // Look for an existing NFC card for this citizen
    let card = await NfcCard.findOne({ patientId: citizen._id, status: 'active' });

    if (!card || !card.rawToken) {
      // Generate a fresh 64-char hex raw token
      const rawToken = crypto.randomBytes(32).toString('hex');
      const hashedToken = crypto.createHash('sha256').update(rawToken).digest('hex');
      const publicCardId = `card-${citizen.profileId}-${Date.now()}`;

      if (card) {
        // Patch existing card with rawToken
        card.rawToken = rawToken;
        card.hashedToken = hashedToken;
        await card.save();
      } else {
        card = await NfcCard.create({
          patientId: citizen._id,
          rawToken,
          hashedToken,
          publicCardId,
          status: 'active',
        });
      }
      console.log(`🔑 Generated new NFC token for citizen: ${citizen.fullName} (${citizen.profileId})`);
    }

    const nfcUrl = `https://www.nfc.swasthyatap.in/card/${card.rawToken}`;
    res.json({
      success: true,
      nfcUrl,
      patientName: citizen.fullName,
      swasthyaId: citizen.profileId,
    });
  } catch (err) {
    console.error('nfc-token error:', err);
    res.status(500).json({ success: false, message: 'Failed to generate NFC token' });
  }
});

// ─── POST /api/citizens/:id/prescriptions ─────────────────────────────────────
// Hospital-authenticated: Add a new prescription to a patient's record
router.post('/:id/prescriptions', authenticate, upload.single('file'), async (req, res) => {
  try {
    if (!req.user.hospitalId) {
      return res.status(403).json({ success: false, message: 'Only hospital personnel can add prescriptions' });
    }

    const citizen = await Citizen.findOne({ profileId: req.params.id });
    if (!citizen) {
      return res.status(404).json({ success: false, message: 'Patient not found' });
    }

    const {
      doctorName,
      qualification,
      hospitalName,
      date,
      diagnosis,
      rxList,
      doctorNotes,
      status,
      // Extra high-fidelity fields
      doctorPhoto,
      validUntil,
      testsRecommended,
      isFavorite,
    } = req.body;

    if (!doctorName || !hospitalName || !date || !diagnosis || !rxList) {
      return res.status(400).json({ success: false, message: 'Missing required prescription fields' });
    }

    let rxListParsed = [];
    if (typeof rxList === 'string') {
      try {
        rxListParsed = JSON.parse(rxList);
      } catch (e) {
        return res.status(400).json({ success: false, message: 'Invalid rxList JSON string' });
      }
    } else if (Array.isArray(rxList)) {
      rxListParsed = rxList;
    } else {
      return res.status(400).json({ success: false, message: 'rxList must be an array or a JSON string' });
    }

    let secureUrl = '';
    if (req.file) {
      const originalName = req.file.originalname || `prescription_${Date.now()}.pdf`;
      const uploadResult = await uploadToCloudinary(req.file.buffer, originalName);
      secureUrl = uploadResult.secure_url;
    }

    let parsedTests = [];
    if (testsRecommended) {
      if (typeof testsRecommended === 'string') {
        try {
          parsedTests = JSON.parse(testsRecommended);
        } catch (_) {
          parsedTests = [testsRecommended];
        }
      } else if (Array.isArray(testsRecommended)) {
        parsedTests = testsRecommended;
      }
    }

    const newPrescription = {
      prescriptionId: `PRES-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      doctorName,
      qualification: qualification || '',
      hospitalName,
      date,
      diagnosis,
      doctorNotes: doctorNotes || '',
      pdfUrl: secureUrl,
      status: status || 'Active',
      doctorPhoto: doctorPhoto || '',
      validUntil: validUntil || '',
      testsRecommended: parsedTests,
      isFavorite: isFavorite === 'true' || isFavorite === true,
      rxList: rxListParsed.map(item => ({
        medicineName: item.medicineName || item.name || '',
        dosage: item.dosage || item.strength || '',
        frequency: item.frequency || '',
        duration: item.duration || '',
        instructions: item.instructions || '',
        morning: item.morning === true || item.morning === 'true',
        afternoon: item.afternoon === true || item.afternoon === 'true',
        night: item.night === true || item.night === 'true',
        beforeFood: item.beforeFood === true || item.beforeFood === 'true',
        afterFood: item.afterFood === true || item.afterFood === 'true',
        quantity: item.quantity || '',
        purpose: item.purpose || '',
        sideEffects: item.sideEffects || '',
        storage: item.storage || '',
        alternatives: item.alternatives || '',
        isTakenToday: item.isTakenToday === true || item.isTakenToday === 'true',
      })),
    };

    citizen.prescriptions.push(newPrescription);
    await citizen.save();

    console.log(`💊 Prescription added and uploaded for citizen: ${citizen.fullName} (${citizen.profileId})`);
    res.json({ success: true, citizen: formatCitizen(citizen) });
  } catch (err) {
    console.error('Add prescription error:', err);
    res.status(500).json({ success: false, message: 'Failed to add prescription' });
  }
});

// ─── POST /api/citizens/:id/medical-reports ───────────────────────────────────
// Hospital-authenticated: Upload a medical report file and append metadata
router.post('/:id/medical-reports', authenticate, upload.single('file'), async (req, res) => {
  try {
    if (!req.user.hospitalId) {
      return res.status(403).json({ success: false, message: 'Only hospital personnel can upload medical reports' });
    }

    const citizen = await Citizen.findOne({ profileId: req.params.id });
    if (!citizen) {
      return res.status(404).json({ success: false, message: 'Patient not found' });
    }

    const {
      title_key,
      issuer_key,
      date,
      status_key,
      doctor_key,
      // High-fidelity fields
      department,
      bloodGroup,
      tags,
      category,
      uploadedBy,
      fileType,
      notes,
      isAbnormal,
      isFavorite,
      fileSize,
      referenceId,
      version,
    } = req.body;

    if (!title_key || !issuer_key || !date) {
      return res.status(400).json({ success: false, message: 'Missing required report fields' });
    }

    let secureUrl = '';
    let originalName = 'report.jpg';

    if (req.file) {
      originalName = req.file.originalname;
      const uploadResult = await uploadToCloudinary(req.file.buffer, originalName);
      secureUrl = uploadResult.secure_url;
    } else {
      return res.status(400).json({ success: false, message: 'No file uploaded' });
    }

    let parsedTags = [];
    if (tags) {
      if (typeof tags === 'string') {
        try {
          parsedTags = JSON.parse(tags);
        } catch (_) {
          parsedTags = [tags];
        }
      } else if (Array.isArray(tags)) {
        parsedTags = tags;
      }
    } else {
      parsedTags = [category || 'Others', 'Lab Upload'];
    }

    const newReport = {
      name: originalName,
      url: secureUrl,
      uploadedAt: new Date(),
      title_key,
      issuer_key,
      date,
      status_key: status_key || 'verified_report',
      doctor_key: doctor_key || '',
      department: department || 'General Medicine',
      bloodGroup: bloodGroup || null,
      tags: parsedTags,
      category: category || 'Others',
      uploadedBy: uploadedBy || issuer_key || '',
      fileType: fileType || (originalName.toLowerCase().endsWith('.pdf') ? 'PDF' : 'JPG'),
      notes: notes || status_key || '',
      isAbnormal: isAbnormal === 'true' || isAbnormal === true,
      isFavorite: isFavorite === 'true' || isFavorite === true,
      fileSize: fileSize || '1.2 MB',
      referenceId: referenceId || `REF-${Date.now()}`,
      version: version || '1.0.0',
    };

    citizen.medicalReports.push(newReport);
    await citizen.save();

    console.log(`📄 Medical report uploaded for citizen: ${citizen.fullName} (${citizen.profileId})`);
    res.json({ success: true, citizen: formatCitizen(citizen) });
  } catch (err) {
    console.error('Upload medical report error:', err);
    res.status(500).json({ success: false, message: 'Failed to upload medical report' });
  }
});

module.exports = router;
