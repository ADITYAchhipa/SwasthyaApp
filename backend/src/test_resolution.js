require('dotenv').config();
const mongoose = require('mongoose');
const Citizen = require('./models/Citizen');
const NfcCard = require('./models/NfcCard');
const crypto = require('crypto');
const http = require('http');

async function test() {
  const dbUri = process.env.MONGO_URI;
  await mongoose.connect(dbUri);
  console.log("Connected to MongoDB");

  const citizen = await Citizen.findOne({ profileId: 'x7k9m2' });
  if (!citizen) {
    console.error("Test citizen x7k9m2 not found!");
    process.exit(1);
  }
  console.log("Citizen name:", citizen.fullName);

  // 1. Test profileId resolution
  console.log("\n--- Testing Direct Profile ID Resolution ---");
  await checkResolve('x7k9m2');

  // 2. Test fallback hash resolution
  console.log("\n--- Testing SHA-256 Fallback Hash Resolution ---");
  const fallbackHash = crypto.createHash('sha256').update('x7k9m2').digest('hex');
  console.log("Fallback hash:", fallbackHash);
  await checkResolve(fallbackHash);

  // 3. Test active card token resolution
  console.log("\n--- Testing Active Card Token Resolution ---");
  let card = await NfcCard.findOne({ patientId: citizen._id, status: 'active' });
  if (card && card.rawToken) {
    console.log("Active card token:", card.rawToken);
    await checkResolve(card.rawToken);
  } else {
    console.log("No card found for citizen, creating a temporary one...");
    const rawToken = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto.createHash('sha256').update(rawToken).digest('hex');
    card = await NfcCard.create({
      patientId: citizen._id,
      cardType: 'free',
      status: 'active',
      publicCardId: `card-x7k9m2-${Date.now()}`,
      rawToken,
      hashedToken
    });
    console.log("Created card token:", rawToken);
    await checkResolve(rawToken);
    await NfcCard.deleteOne({ _id: card._id });
    console.log("Deleted temporary card");
  }

  await mongoose.disconnect();
}

function checkResolve(id) {
  return new Promise((resolve) => {
    http.get(`http://localhost:3011/api/citizens/${id}`, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        console.log(`Resolution for ${id}: Status = ${res.statusCode}`);
        try {
          const body = JSON.parse(data);
          console.log("  Success:", body.success);
          console.log("  Name:", body.citizen ? body.citizen.fullName : 'null');
        } catch (e) {
          console.log("  Body:", data);
        }
        resolve();
      });
    });
  });
}

test().catch(console.error);
