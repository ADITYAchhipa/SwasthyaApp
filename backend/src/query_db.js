require('dotenv').config();
const mongoose = require('mongoose');
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/swasthyatap';

mongoose.connect(mongoUri)
  .then(async () => {
    console.log('Connected to MongoDB:', mongoUri.split('@')[1] || mongoUri);
    
    const CitizenSchema = new mongoose.Schema({
      profileId: String,
      fullName: String,
    });
    const Citizen = mongoose.model('Citizen', CitizenSchema);
    
    const NfcCardSchema = new mongoose.Schema({
      patientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Citizen' },
      rawToken: String,
      hashedToken: String,
      status: String,
    });
    const NfcCard = mongoose.model('NFCCard', NfcCardSchema);

    const citizens = await Citizen.find({});
    console.log('\n--- CITIZENS ---');
    for (const c of citizens) {
      console.log(`ID: ${c.profileId} | Name: ${c.fullName} | _id: ${c._id}`);
      
      const cards = await NfcCard.find({ patientId: c._id });
      for (const card of cards) {
        console.log(`  -> Card Status: ${card.status} | rawToken: ${card.rawToken} | hashedToken: ${card.hashedToken}`);
      }
    }
    
    mongoose.disconnect();
  })
  .catch(err => {
    console.error(err);
  });
