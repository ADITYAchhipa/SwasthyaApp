const mongoose = require('mongoose');

const MONGO_URI = "mongodb+srv://adichhipa2_db_user:Oo2WWuEiChjI7Ab8@swasthyatap.abo8hz9.mongodb.net/swasthyatap?appName=swasthyatap";

async function run() {
  await mongoose.connect(MONGO_URI);
  console.log("Connected to MongoDB.");

  // Define schemas inline to avoid dependency path issues
  const CitizenSchema = new mongoose.Schema({
    profileId: String,
    fullName: String
  }, { collection: 'citizens' });

  const NfcCardSchema = new mongoose.Schema({
    patientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Citizen' },
    rawToken: String,
    hashedToken: String,
    publicCardId: String,
    status: String,
  }, { collection: 'nfccards' });

  const Citizen = mongoose.models.Citizen || mongoose.model('Citizen', CitizenSchema);
  const NfcCard = mongoose.models.NFCCard || mongoose.model('NFCCard', NfcCardSchema);

  const cards = await NfcCard.find({}).populate('patientId');
  console.log(`\n--- FOUND ${cards.length} NFC CARDS ---`);
  for (const card of cards) {
    console.log({
      id: card._id,
      status: card.status,
      publicCardId: card.publicCardId,
      rawToken: card.rawToken,
      hashedToken: card.hashedToken,
      patientId: card.patientId ? {
        id: card.patientId._id,
        profileId: card.patientId.profileId,
        fullName: card.patientId.fullName
      } : null
    });
  }

  await mongoose.disconnect();
}

run().catch(console.error);
