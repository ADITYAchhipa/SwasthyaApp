const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const Hospital = require('../models/Hospital');

// Shared read; the projection excludes personnel and internal staff login phone.
async function readHospital(hospitalId) {
  return Hospital.findOne({ hospitalId }, { authorizedPersonnel: 0, registeredPhone: 0 });
}

// ─── Middleware: Hospital Authentication & Role-Based Access Control ─────────
function requireHospitalAuth(allowedRoles) {
  return async (req, res, next) => {
    try {
      const authHeader = req.get('Authorization') || '';
      if (!authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ success: false, message: 'Unauthorized: missing token' });
      }
      const token = authHeader.slice(7);
      const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
      if (!decoded.hospitalId || !decoded.personnelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized: invalid hospital token' });
      }
      if (req.params.hospitalId && decoded.hospitalId !== req.params.hospitalId) {
        return res.status(403).json({ success: false, message: 'Forbidden: token belongs to another hospital' });
      }

      const hospital = await Hospital.findOne({
        hospitalId: decoded.hospitalId,
        isVerified: true,
      });
      if (!hospital) {
        return res.status(404).json({ success: false, message: 'Hospital not found or unverified' });
      }

      const personnel = hospital.authorizedPersonnel?.find(p => p.personnelId === decoded.personnelId);
      if (!personnel) {
        return res.status(403).json({ success: false, message: 'Forbidden: personnel no longer authorized' });
      }

      const role = personnel.role || decoded.role || 'doctor';
      if (allowedRoles && !allowedRoles.includes(role)) {
        return res.status(403).json({
          success: false,
          message: `Forbidden: role '${role}' not authorized. Requires: [${allowedRoles.join(', ')}]`,
        });
      }

      req.hospital = hospital;
      req.personnel = personnel;
      req.personnelRole = role;
      next();
    } catch (err) {
      return res.status(401).json({ success: false, message: 'Unauthorized', error: err.message });
    }
  };
}

// ─── GET /api/hospitals ───────────────────────────────────────────────────────
// Get all hospitals (optionally filter by city, specialty, or search)
router.get('/', async (req, res) => {
  try {
    const { city, specialty, search } = req.query;
    const filter = {};
    if (city) filter.city = new RegExp(city, 'i');
    if (specialty) filter.specialties = specialty;
    if (search) {
      filter.$or = [
        { name: new RegExp(search, 'i') },
        { address: new RegExp(search, 'i') },
      ];
    }

    const hospitals = await Hospital.find(filter, {
      authorizedPersonnel: 0, // Never expose personnel list publicly
      registeredPhone: 0,     // Never expose staff login phone publicly
    }).sort({ name: 1 });

    res.json({ success: true, hospitals });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

// ─── GET /api/hospitals/:hospitalId ──────────────────────────────────────────
router.get('/:hospitalId', async (req, res) => {
  try {
    const hospital = await readHospital(req.params.hospitalId);
    if (!hospital) return res.status(404).json({ success: false, message: 'Hospital not found' });
    res.json({ success: true, hospital });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

// ─── GET /api/hospitals/:hospitalId/personnel ─────────────────────────────────
// View staff directory - accessible by doctor and supervisor
router.get('/:hospitalId/personnel', requireHospitalAuth(['doctor', 'supervisor']), async (req, res) => {
  res.json({
    success: true,
    personnel: req.hospital.authorizedPersonnel || [],
  });
});

// ─── POST /api/hospitals/:hospitalId/personnel ────────────────────────────────
// Add new personnel - SUPERVISOR ONLY
router.post('/:hospitalId/personnel', requireHospitalAuth(['supervisor']), async (req, res) => {
  try {
    const { personnelId, name, designation, role = 'doctor' } = req.body;
    if (!personnelId || !name) {
      return res.status(400).json({ success: false, message: 'personnelId and name are required' });
    }
    if (!['doctor', 'supervisor', 'staff'].includes(role)) {
      return res.status(400).json({ success: false, message: 'Invalid role. Must be doctor, supervisor, or staff' });
    }

    const hospital = req.hospital;
    if (hospital.authorizedPersonnel?.some(p => p.personnelId === personnelId)) {
      return res.status(409).json({ success: false, message: 'Personnel ID already exists in this hospital' });
    }

    hospital.authorizedPersonnel = hospital.authorizedPersonnel || [];
    hospital.authorizedPersonnel.push({
      personnelId,
      name,
      designation: designation || (role === 'doctor' ? 'Medical Officer' : 'Hospital Supervisor'),
      role,
    });
    await hospital.save();

    res.json({
      success: true,
      message: `Personnel ${name} added successfully as ${role}`,
      personnel: hospital.authorizedPersonnel,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

// ─── DELETE /api/hospitals/:hospitalId/personnel/:personnelId ─────────────────
// Remove personnel - SUPERVISOR ONLY
router.delete('/:hospitalId/personnel/:personnelId', requireHospitalAuth(['supervisor']), async (req, res) => {
  try {
    const { personnelId } = req.params;
    const hospital = req.hospital;

    const index = hospital.authorizedPersonnel?.findIndex(p => p.personnelId === personnelId);
    if (index === -1 || index === undefined) {
      return res.status(404).json({ success: false, message: 'Personnel not found' });
    }

    // Prevent supervisor from removing themselves if they are the only supervisor
    if (personnelId === req.personnel.personnelId) {
      const supervisorCount = hospital.authorizedPersonnel.filter(p => p.role === 'supervisor').length;
      if (supervisorCount <= 1) {
        return res.status(400).json({
          success: false,
          message: 'Cannot remove yourself as the only hospital supervisor',
        });
      }
    }

    hospital.authorizedPersonnel.splice(index, 1);
    await hospital.save();

    res.json({
      success: true,
      message: 'Personnel removed successfully',
      personnel: hospital.authorizedPersonnel,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

// ─── PUT /api/hospitals/:hospitalId/beds ──────────────────────────────────────
// Update bed count and capacity - DOCTOR or SUPERVISOR
router.put('/:hospitalId/beds', requireHospitalAuth(['doctor', 'supervisor']), async (req, res) => {
  try {
    const { bedCount, status, statusDetails } = req.body;
    const hospital = req.hospital;

    if (bedCount !== undefined) {
      hospital.bedCount = Math.max(0, parseInt(bedCount, 10) || 0);
    }
    if (status) hospital.status = status;
    if (statusDetails) hospital.statusDetails = statusDetails;

    await hospital.save();

    res.json({
      success: true,
      message: 'Hospital capacity updated successfully',
      bedCount: hospital.bedCount,
      status: hospital.status,
      statusDetails: hospital.statusDetails,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

router.readHospital = readHospital;
module.exports = router;
