const express = require('express');
const router = express.Router();
const Hospital = require('../models/Hospital');

// ─── GET /api/hospitals ───────────────────────────────────────────────────────
// Get all hospitals (optionally filter by city or specialty)
router.get('/', async (req, res) => {
  try {
    const { city, specialty } = req.query;
    const filter = {};
    if (city) filter.city = new RegExp(city, 'i');
    if (specialty) filter.specialties = specialty;

    const hospitals = await Hospital.find(filter, {
      authorizedPersonnel: 0, // Never expose personnel list publicly
    }).sort({ name: 1 });

    res.json({ success: true, hospitals });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ─── GET /api/hospitals/:hospitalId ──────────────────────────────────────────
router.get('/:hospitalId', async (req, res) => {
  try {
    const hospital = await Hospital.findOne(
      { hospitalId: req.params.hospitalId },
      { authorizedPersonnel: 0 }
    );
    if (!hospital) return res.status(404).json({ success: false, message: 'Hospital not found' });
    res.json({ success: true, hospital });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
