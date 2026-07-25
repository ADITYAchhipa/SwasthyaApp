/**
 * SwasthyaTap Database Seed Script
 * Run with: node src/seed/seed.js
 *
 * Seeds:
 *  - 5 demo citizens (matching the original Flutter mock profiles)
 *  - 3 demo hospitals with authorized personnel
 */

require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const mongoose = require('mongoose');
const crypto = require('crypto');
const Citizen = require('../models/Citizen');
const Hospital = require('../models/Hospital');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/swasthyatap';

async function generateHash(citizenId, fullName, date, organs) {
  const payload = `${citizenId}|${fullName}|${date}|${organs.join(',')}`;
  return crypto.createHash('sha256').update(payload).digest('hex');
}

async function seed() {
  console.log('\n🌱 SwasthyaTap Seed Script Starting...\n');

  await mongoose.connect(MONGO_URI);
  console.log('✅ Connected to MongoDB:', MONGO_URI);

  // ─── Clear existing data ──────────────────────────────────────────────────
  await Citizen.deleteMany({});
  await Hospital.deleteMany({});
  console.log('🗑️  Cleared existing citizens and hospitals.\n');

  // ─── Citizens ─────────────────────────────────────────────────────────────
  const dateStr = new Date().toISOString().split('T')[0];

  const rajeshHash = await generateHash('x7k9m2', 'Rajesh Kumar', dateStr, ['Corneas', 'Heart', 'Kidneys']);
  const amitHash = await generateHash('a2m9b7', 'Amit Verma', dateStr, ['All Organs', 'Tissues']);

  const citizens = [
    {
      profileId: 'x7k9m2',
      phoneNumber: '9900112233',
      email: 'rajesh@example.com',
      fullName: 'Rajesh Kumar',
      bloodGroup: 'B+',
      allergies: 'None',
      medications: 'None',
      chronicConditions: 'None',
      specialInstructions: 'None',
      isDnr: false,
      emergencyContacts: [
        { name: 'Sneha Kumar', relation: 'Spouse', phone: '+91 98765 43210' },
        { name: 'Anil Kumar', relation: 'Father', phone: '+91 98765 01234' },
      ],
      organPledge: {
        pledgeId: 'NOTTO-X7K9M2',
        pledgedOrgans: ['Corneas', 'Heart', 'Kidneys'],
        signedDate: dateStr,
        signatureHash: rajeshHash,
        nottoVerified: true,
      },
      insuranceCompany: 'HDFC Ergo Health Optima',
      insurancePolicyNumber: 'POL-8873491-02',
      lifeCredits: 350,
      isBloodDonor: true,
      donorRadiusKm: 5.0,
      homeLat: 12.9722,
      homeLng: 77.5938,
      medicalReports: [
        {
          title_key: 'cbc_report',
          issuer_key: 'lab_name_city',
          date: '18 Jun 2026',
          status_key: 'verified_report',
          doctor_key: 'dr_amit_shah',
        },
        {
          title_key: 'lipid_profile',
          issuer_key: 'lab_name_apollo',
          date: '10 May 2026',
          status_key: 'verified_report',
          doctor_key: 'dr_patel',
        },
        {
          title_key: 'thyroid_report',
          issuer_key: 'lab_name_city',
          date: '24 Apr 2026',
          status_key: 'verified_report',
          doctor_key: 'dr_singh',
        },
        {
          title_key: 'chest_xray',
          issuer_key: 'lab_name_apollo',
          date: '15 Feb 2026',
          status_key: 'verified_report',
          doctor_key: 'dr_amit_shah',
        }
      ],
      receipts: [
        {
          title_key: 'opd_consultation_receipt',
          issuer_key: 'dr_amit_shah',
          date: '20 Jun 2026',
          amount: '₹500',
          status_key: 'paid',
        },
        {
          title_key: 'pharmacy_invoice',
          issuer_key: 'apollo_pharmacy',
          date: '20 Jun 2026',
          amount: '₹1,240',
          status_key: 'paid',
        },
        {
          title_key: 'diagnostics_invoice',
          issuer_key: 'city_labs',
          date: '12 May 2026',
          amount: '₹1,500',
          status_key: 'paid',
        }
      ],
    },
    {
      profileId: 'p3n8k1',
      phoneNumber: '9912234455',
      email: 'priya@example.com',
      fullName: 'Priya Patel',
      bloodGroup: 'A+',
      allergies: 'Peanut allergy, Latex',
      medications: 'None',
      chronicConditions: 'None',
      specialInstructions: 'Severe peanut allergy. Epipen in backpack.',
      isDnr: false,
      emergencyContacts: [
        { name: 'Ketan Patel', relation: 'Brother', phone: '+91 99223 34455' },
      ],
      insuranceCompany: 'Star Health Assure',
      insurancePolicyNumber: 'POL-1092842',
      lifeCredits: 800,
      isBloodDonor: true,
      donorRadiusKm: 4.5,
      homeLat: 12.9592,
      homeLng: 77.5978,
    },
    {
      profileId: 'a2m9b7',
      phoneNumber: '9933445566',
      email: 'amit@example.com',
      fullName: 'Amit Verma',
      bloodGroup: 'O-',
      allergies: 'None',
      medications: 'Metformin 500mg',
      chronicConditions: 'Type-2 Diabetes',
      specialInstructions: 'Type-2 Diabetic. DNR active. See medical directive.',
      isDnr: true,
      emergencyContacts: [
        { name: 'Sunita Verma', relation: 'Mother', phone: '+91 99887 76655' },
      ],
      organPledge: {
        pledgeId: 'NOTTO-A2M9B7',
        pledgedOrgans: ['All Organs', 'Tissues'],
        signedDate: dateStr,
        signatureHash: amitHash,
        nottoVerified: true,
      },
      insuranceCompany: 'ICICI Lombard Health Shield',
      insurancePolicyNumber: 'POL-7763102',
      lifeCredits: 1200,
      isBloodDonor: true,
      donorRadiusKm: 6.0,
      homeLat: 12.9782,
      homeLng: 77.5912,
    },
    {
      profileId: 'v5t2y8',
      phoneNumber: '9956677889',
      email: 'vikram@example.com',
      fullName: 'Dr. Vikram Roy',
      bloodGroup: 'B+',
      allergies: 'Aspirin',
      medications: 'Atorvastatin 10mg',
      chronicConditions: 'Hypertension',
      specialInstructions: 'Hypertension. Has medical ID bracelet.',
      isDnr: false,
      emergencyContacts: [
        { name: 'Ritu Roy', relation: 'Spouse', phone: '+91 99556 67788' },
      ],
      insuranceCompany: 'Niva Bupa Health Companion',
      insurancePolicyNumber: 'POL-5542109',
      lifeCredits: 50,
      isBloodDonor: true,
      donorRadiusKm: 3.0,
      homeLat: 12.9855,
      homeLng: 77.6385,
    },
    {
      profileId: 'm1s4q9',
      phoneNumber: '9988990011',
      email: 'meera@example.com',
      fullName: 'Meera Sen',
      bloodGroup: 'O+',
      allergies: 'None',
      medications: 'None',
      chronicConditions: 'None',
      specialInstructions: 'None',
      isDnr: false,
      emergencyContacts: [
        { name: 'Rajesh Sen', relation: 'Father', phone: '+91 99778 89900' },
      ],
      insuranceCompany: 'Aditya Birla Activ Health',
      insurancePolicyNumber: 'POL-4432190',
      lifeCredits: 600,
      isBloodDonor: true,
      donorRadiusKm: 5.0,
      homeLat: 12.9648,
      homeLng: 77.5960,
    },
  ];

  await Citizen.insertMany(citizens);
  console.log(`✅ Seeded ${citizens.length} demo citizens:`);
  citizens.forEach((c) => console.log(`   → ${c.fullName} (${c.profileId}) — ${c.bloodGroup}`));

  // ─── Hospitals ────────────────────────────────────────────────────────────
  const hospitals = [
    {
      hospitalId: 'HOSP-001',
      name: 'Bangalore Government Medical College & Hospital',
      address: 'Fort Road, KR Market, Bangalore',
      city: 'Bangalore',
      state: 'Karnataka',
      lat: 12.9636,
      lng: 77.5843,
      registeredPhone: '9900112233',
      authorizedPersonnel: [
        { personnelId: 'STAFF-001', name: 'Dr. Suresh Babu', designation: 'Emergency Head' },
        { personnelId: 'STAFF-002', name: 'Nurse Kavitha', designation: 'Senior Nurse' },
      ],
      specialties: ['Emergency', 'Cardiology', 'Orthopedics'],
      bedCount: 850,
      isVerified: true,
    },
    {
      hospitalId: 'HOSP-002',
      name: 'St. John\'s Medical College Hospital',
      address: 'Sarjapur Road, Koramangala, Bangalore',
      city: 'Bangalore',
      state: 'Karnataka',
      lat: 12.9350,
      lng: 77.6231,
      registeredPhone: '9900112233',
      authorizedPersonnel: [
        { personnelId: 'STAFF-003', name: 'Dr. Mary Thomas', designation: 'Chief Medical Officer' },
        { personnelId: 'STAFF-004', name: 'Dr. Anand Kumar', designation: 'Resident Doctor' },
      ],
      specialties: ['Neurology', 'Oncology', 'Pediatrics'],
      bedCount: 1200,
      isVerified: true,
    },
    {
      hospitalId: 'HOSP-003',
      name: 'Victoria Hospital',
      address: 'K.R. Road, Shivajinagar, Bangalore',
      city: 'Bangalore',
      state: 'Karnataka',
      lat: 12.9716,
      lng: 77.5720,
      registeredPhone: '9900112233',
      authorizedPersonnel: [
        { personnelId: 'STAFF-005', name: 'Dr. Pradeep Rao', designation: 'Trauma Specialist' },
      ],
      specialties: ['Trauma', 'General Surgery', 'Emergency'],
      bedCount: 600,
      isVerified: true,
    },
  ];

  await Hospital.insertMany(hospitals);
  console.log(`\n✅ Seeded ${hospitals.length} demo hospitals:`);
  hospitals.forEach((h) => console.log(`   → ${h.name} (${h.hospitalId})`));

  console.log('\n─────────────────────────────────────────────────────────────');
  console.log('📋 Demo Hospital Login Credentials:');
  console.log('   Hospital ID : HOSP-001  |  Personnel ID: STAFF-001');
  console.log('   Hospital ID : HOSP-002  |  Personnel ID: STAFF-003');
  console.log('   Hospital ID : HOSP-003  |  Personnel ID: STAFF-005');
  console.log('   OTP Phone   : 9900112233 (same for all demo hospitals)');
  console.log('─────────────────────────────────────────────────────────────');
  console.log('\n📋 Demo Citizen Login:');
  console.log('   Any email address → OTP will be shown in server terminal');
  console.log('   Existing demo email: rajesh@example.com (Rajesh Kumar)');
  console.log('─────────────────────────────────────────────────────────────\n');

  await mongoose.disconnect();
  console.log('✅ Seed complete. MongoDB connection closed.\n');
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
