const express = require('express');
const router = express.Router();
const Order = require('../models/Order');
const { authenticate } = require('../middleware/auth');

// ─── POST /api/orders ─────────────────────────────────────────────────────────
// Place an NFC card order — requires auth
router.post('/', authenticate, async (req, res) => {
  try {
    const { cardType, price, deliveryAddress, city, state, pincode, citizenName, phone } = req.body;

    if (!deliveryAddress || !city || !state || !pincode) {
      return res.status(400).json({ success: false, message: 'Delivery address details are required' });
    }

    // Generate unique order ID: STAP + 8 random digits
    const orderId = `STAP${Math.floor(10000000 + Math.random() * 90000000)}`;

    // Estimated delivery: 5-7 business days from now
    const estimatedDelivery = new Date();
    estimatedDelivery.setDate(estimatedDelivery.getDate() + 7);

    const order = await Order.create({
      orderId,
      citizenId: req.user.citizenId,
      citizenName: citizenName || 'SwasthyaTap User',
      phone: phone || '',
      cardType: cardType || 'free',
      price: price || 0,
      deliveryAddress,
      city,
      state,
      pincode,
      status: 'ordered',
      statusStep: 0,
      estimatedDelivery,
    });

    console.log(`\n📦 New order placed: ${orderId} (${cardType} card) for citizen ${req.user.citizenId}\n`);

    res.status(201).json({
      success: true,
      orderId: order.orderId,
      status: order.status,
      statusStep: order.statusStep,
      estimatedDelivery: order.estimatedDelivery,
      placedAt: order.createdAt,
    });
  } catch (err) {
    console.error('place order error:', err);
    res.status(500).json({ success: false, message: 'Failed to place order' });
  }
});

// ─── GET /api/orders/my ───────────────────────────────────────────────────────
// Get all orders for the logged-in citizen
router.get('/my', authenticate, async (req, res) => {
  try {
    const orders = await Order.find({ citizenId: req.user.citizenId }).sort({ createdAt: -1 });
    res.json({ success: true, orders });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch orders' });
  }
});

// ─── GET /api/orders/:orderId ─────────────────────────────────────────────────
// Get a specific order by order ID
router.get('/:orderId', async (req, res) => {
  try {
    const order = await Order.findOne({ orderId: req.params.orderId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    res.json({ success: true, order });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
