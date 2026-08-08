const express = require('express');
const router = express.Router();
const Phc = require('../models/Phc');

// ─── GET /api/phcs ────────────────────────────────────────────────────────────
// Get all PHCs with optional filtering by city or search
router.get('/', async (req, res) => {
  try {
    const { city, search } = req.query;
    const filter = {};
    if (city) filter.city = new RegExp(city, 'i');
    if (search) {
      filter.$or = [
        { name: new RegExp(search, 'i') },
        { address: new RegExp(search, 'i') },
      ];
    }

    const phcs = await Phc.find(filter).sort({ name: 1 });
    res.json({ success: true, phcs });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

// ─── GET /api/phcs/:phcId ─────────────────────────────────────────────────────
router.get('/:phcId', async (req, res) => {
  try {
    const phc = await Phc.findOne({ phcId: req.params.phcId });
    if (!phc) return res.status(404).json({ success: false, message: 'PHC not found' });
    res.json({ success: true, phc });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error', error: err.message });
  }
});

module.exports = router;
