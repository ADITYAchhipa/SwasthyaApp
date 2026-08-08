const express = require('express');
const router = express.Router();
const BloodBank = require('../models/BloodBank');

// ─── GET /api/blood-banks ─────────────────────────────────────────────────────
// Get all Blood Banks with optional filtering by city, bloodGroup, or search
router.get('/', async (req, res) => {
  try {
    const { city, bloodGroup, search } = req.query;
    const filter = {};
    if (city) filter.city = new RegExp(city, 'i');
    if (bloodGroup) filter.availableGroups = bloodGroup;
    if (search) {
      filter.$or = [
        { name: new RegExp(search, 'i') },
        { address: new RegExp(search, 'i') },
      ];
    }

    const bloodBanks = await BloodBank.find(filter).sort({ name: 1 });
    res.json({ success: true, bloodBanks });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

// ─── GET /api/blood-banks/:bloodBankId ─────────────────────────────────────────
router.get('/:bloodBankId', async (req, res) => {
  try {
    const bloodBank = await BloodBank.findOne({ bloodBankId: req.params.bloodBankId });
    if (!bloodBank) return res.status(404).json({ success: false, message: 'Blood Bank not found' });
    res.json({ success: true, bloodBank });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

module.exports = router;
