const express = require('express');
const router = express.Router();
const BloodRequest = require('../models/BloodRequest');
const Citizen = require('../models/Citizen');
const { authenticate, optionalAuth } = require('../middleware/auth');

// ─── Helper: Blood group compatibility ───────────────────────────────────────
function isCompatible(patientGroup, donorGroup) {
  if (donorGroup === 'O-') return true;
  if (patientGroup === donorGroup) return true;
  if (patientGroup === 'AB+') return true;
  if (patientGroup === 'O+' && (donorGroup === 'O+' || donorGroup === 'O-')) return true;
  if (patientGroup === 'A+' && ['A+', 'A-', 'O+', 'O-'].includes(donorGroup)) return true;
  if (patientGroup === 'B+' && ['B+', 'B-', 'O+', 'O-'].includes(donorGroup)) return true;
  return false;
}

// ─── Helper: Haversine distance in km ────────────────────────────────────────
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─── POST /api/blood-requests ─────────────────────────────────────────────────
// Declare a blood emergency — called by hospital portal
router.post('/', authenticate, async (req, res) => {
  try {
    const { hospitalName, hospitalAddress, bloodGroup, unitsNeeded, lat, lng, radiusKm } = req.body;

    if (!hospitalName || !bloodGroup || !unitsNeeded || lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    const requestId = `REQ-${Date.now().toString().slice(-8)}`;
    const radius = radiusKm || 10;

    // Find all matching blood donors within radius
    const allDonors = await Citizen.find({ isBloodDonor: true });
    const matchingDonors = [];

    for (const donor of allDonors) {
      if (isCompatible(bloodGroup, donor.bloodGroup)) {
        const distance = haversineKm(lat, lng, donor.homeLat, donor.homeLng);
        if (distance <= radius) {
          matchingDonors.push({
            donorId: donor.profileId,
            donorName: donor.fullName,
            phone: donor.phoneNumber,
            status: 'pending',
            etaMinutes: 0,
            lat: donor.homeLat,
            lng: donor.homeLng,
          });
        }
      }
    }

    const bloodRequest = await BloodRequest.create({
      requestId,
      hospitalName,
      hospitalAddress: hospitalAddress || '',
      bloodGroup,
      unitsNeeded,
      lat,
      lng,
      radiusKm: radius,
      status: 'active',
      responses: matchingDonors,
      declaredBy: req.user.hospitalId || req.user.citizenId,
    });

    console.log(
      `\n🚨 Blood Emergency: ${bloodGroup} needed at ${hospitalName}. ${matchingDonors.length} donors notified.\n`
    );

    res.status(201).json({
      success: true,
      requestId: bloodRequest.requestId,
      donorsNotified: matchingDonors.length,
      bloodRequest: formatRequest(bloodRequest),
    });
  } catch (err) {
    console.error('blood-request error:', err);
    res.status(500).json({ success: false, message: 'Failed to declare emergency' });
  }
});

// ─── GET /api/blood-requests ──────────────────────────────────────────────────
// Get all active blood requests
router.get('/', optionalAuth, async (req, res) => {
  try {
    const { status } = req.query;
    const filter = status ? { status } : { status: 'active' };
    const requests = await BloodRequest.find(filter).sort({ createdAt: -1 }).limit(50);
    res.json({ success: true, requests: requests.map(formatRequest) });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ─── GET /api/blood-requests/:requestId ──────────────────────────────────────
router.get('/:requestId', async (req, res) => {
  try {
    const req_ = await BloodRequest.findOne({ requestId: req.params.requestId });
    if (!req_) return res.status(404).json({ success: false, message: 'Request not found' });
    res.json({ success: true, bloodRequest: formatRequest(req_) });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ─── PUT /api/blood-requests/:requestId/respond ──────────────────────────────
// Donor responds to a blood request
router.put('/:requestId/respond', authenticate, async (req, res) => {
  try {
    const { donorId, responseStatus, eta } = req.body;
    const validStatuses = ['accepted', 'declined'];

    if (!donorId || !validStatuses.includes(responseStatus)) {
      return res.status(400).json({ success: false, message: 'donorId and valid responseStatus required' });
    }

    const bloodRequest = await BloodRequest.findOne({ requestId: req.params.requestId });
    if (!bloodRequest) return res.status(404).json({ success: false, message: 'Request not found' });

    const respIndex = bloodRequest.responses.findIndex((r) => r.donorId === donorId);
    if (respIndex === -1) {
      return res.status(404).json({ success: false, message: 'Donor not found in this request' });
    }

    bloodRequest.responses[respIndex].status = responseStatus;
    bloodRequest.responses[respIndex].etaMinutes = responseStatus === 'accepted' ? (eta || 15) : 0;
    bloodRequest.responses[respIndex].respondedAt = new Date();

    // Award life credits if accepted
    if (responseStatus === 'accepted') {
      await Citizen.findOneAndUpdate(
        { profileId: donorId },
        { $inc: { lifeCredits: 100 } }
      );
      console.log(`\n💚 Donor ${donorId} accepted blood request ${req.params.requestId}. +100 LifeCredits awarded.\n`);
    }

    await bloodRequest.save();

    res.json({ success: true, bloodRequest: formatRequest(bloodRequest) });
  } catch (err) {
    console.error('blood respond error:', err);
    res.status(500).json({ success: false, message: 'Failed to update response' });
  }
});

// ─── Helper: format for API response ─────────────────────────────────────────
function formatRequest(r) {
  return {
    requestId: r.requestId,
    hospitalName: r.hospitalName,
    hospitalAddress: r.hospitalAddress,
    bloodGroup: r.bloodGroup,
    unitsNeeded: r.unitsNeeded,
    lat: r.lat,
    lng: r.lng,
    radiusKm: r.radiusKm,
    status: r.status,
    responses: r.responses,
    timestamp: r.createdAt,
  };
}

module.exports = router;
