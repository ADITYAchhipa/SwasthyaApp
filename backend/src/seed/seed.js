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
const NfcCard = require('../models/NfcCard');

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
  await NfcCard.deleteMany({});
  console.log('🗑️  Cleared existing citizens, hospitals, and NFC mappings.\n');

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
          sampleType: 'Whole Blood (EDTA)',
          labRefNo: 'LAB-CBC-9921',
          testParameters: [
            { parameter: 'Hemoglobin', result: '14.2 g/dL', normalRange: '13.0 - 17.0 g/dL', status: 'Normal' },
            { parameter: 'RBC Count', result: '4.8 M/µL', normalRange: '4.5 - 5.5 M/µL', status: 'Normal' },
            { parameter: 'WBC Count', result: '7,200 /µL', normalRange: '4,000 - 11,000 /µL', status: 'Normal' },
            { parameter: 'Platelet Count', result: '240,000 /µL', normalRange: '150,000 - 450,000 /µL', status: 'Normal' }
          ],
          doctorRemarks: 'All hematological parameters within normal reference ranges.',
          department: 'Hematology',
          tags: ['CBC', 'Blood Test', 'Routine'],
          category: 'Blood Tests',
          uploadedBy: 'City Labs',
          fileType: 'PDF',
          notes: 'All parameters normal.',
          isAbnormal: false,
          isFavorite: false,
          fileSize: '1.8 MB',
          referenceId: 'REF-CBC-9921',
          version: '1.0.0',
        },
        {
          title_key: 'lipid_profile',
          issuer_key: 'lab_name_apollo',
          date: '10 May 2026',
          status_key: 'verified_report',
          doctor_key: 'dr_patel',
          sampleType: 'Fasting Blood Serum',
          labRefNo: 'LAB-LIPID-8834',
          testParameters: [
            { parameter: 'Total Cholesterol', result: '195 mg/dL', normalRange: '< 200 mg/dL', status: 'Normal' },
            { parameter: 'Triglycerides', result: '140 mg/dL', normalRange: '< 150 mg/dL', status: 'Normal' },
            { parameter: 'HDL Cholesterol', result: '48 mg/dL', normalRange: '> 40 mg/dL', status: 'Optimal' },
            { parameter: 'LDL Cholesterol', result: '119 mg/dL', normalRange: '< 130 mg/dL', status: 'Normal' }
          ],
          doctorRemarks: 'Lipid panel desirable. Continue current dietary habits.',
          department: 'Biochemistry',
          tags: ['Lipid', 'Cholesterol', 'Fasting'],
          category: 'Blood Tests',
          uploadedBy: 'Apollo Diagnostics',
          fileType: 'PDF',
          notes: 'Lipid levels within acceptable limits.',
          isAbnormal: false,
          isFavorite: true,
          fileSize: '2.1 MB',
          referenceId: 'REF-LIPID-8834',
          version: '1.0.0',
        },
        {
          title_key: 'thyroid_report',
          issuer_key: 'lab_name_city',
          date: '24 Apr 2026',
          status_key: 'verified_report',
          doctor_key: 'dr_singh',
          sampleType: 'Blood Serum',
          labRefNo: 'LAB-THY-4401',
          testParameters: [
            { parameter: 'TSH (Thyroid Stimulating Hormone)', result: '2.45 µIU/mL', normalRange: '0.55 - 4.78 µIU/mL', status: 'Normal' },
            { parameter: 'Total T3', result: '1.15 ng/mL', normalRange: '0.80 - 2.00 ng/mL', status: 'Normal' },
            { parameter: 'Total T4', result: '8.2 µg/dL', normalRange: '5.1 - 14.1 µg/dL', status: 'Normal' }
          ],
          doctorRemarks: 'Euthyroid state confirmed.',
          department: 'Endocrinology',
          tags: ['Thyroid', 'TSH', 'Hormone'],
          category: 'Blood Tests',
          uploadedBy: 'City Labs',
          fileType: 'PDF',
          notes: 'Normal thyroid function.',
          isAbnormal: false,
          isFavorite: false,
          fileSize: '1.4 MB',
          referenceId: 'REF-THY-4401',
          version: '1.0.0',
        },
        {
          title_key: 'chest_xray',
          issuer_key: 'lab_name_apollo',
          date: '15 Feb 2026',
          status_key: 'verified_report',
          doctor_key: 'dr_amit_shah',
          sampleType: 'Radiology Imaging (PA View)',
          labRefNo: 'RAD-XRAY-1092',
          testParameters: [
            { parameter: 'Lung Fields', result: 'Clear bilateral lung fields', normalRange: 'Clear', status: 'Normal' },
            { parameter: 'Cardiac Shadow', result: 'Normal cardiac size & contour', normalRange: 'Normal CTR', status: 'Normal' },
            { parameter: 'Costophrenic Angles', result: 'Sharp & clear', normalRange: 'Clear', status: 'Normal' }
          ],
          doctorRemarks: 'No focal consolidation, effusion or pneumothorax.',
          department: 'Radiology',
          tags: ['X-Ray', 'Chest', 'Radiology'],
          category: 'Radiology',
          uploadedBy: 'Apollo Diagnostics',
          fileType: 'JPG',
          notes: 'Clear chest radiograph.',
          isAbnormal: false,
          isFavorite: false,
          fileSize: '4.5 MB',
          referenceId: 'REF-XRAY-1092',
          version: '1.0.0',
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
      prescriptions: [
        {
          prescriptionId: 'RX-2026-891',
          doctorName: 'Dr. Amit Shah',
          qualification: 'MD (Cardiology), FACC',
          hospitalName: 'Apollo Speciality Hospital',
          date: '20 Jun 2026',
          diagnosis: 'Mild Hypertension & Preventive Checkup',
          doctorNotes: 'Maintain low sodium diet, 30 mins morning walk recommended. Follow up after 1 month with BP log.',
          status: 'Active',
          doctorPhoto: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?q=80&w=150',
          validUntil: '20 Jul 2026',
          testsRecommended: ['Lipid Profile', 'ECG'],
          isFavorite: true,
          rxList: [
            {
              medicineName: 'Telmisartan 40mg',
              dosage: '1 Tablet',
              frequency: 'Once Daily (Morning)',
              duration: '30 Days',
              instructions: 'Take after breakfast with water',
              morning: true,
              afternoon: false,
              night: false,
              beforeFood: false,
              afterFood: true,
              quantity: '30 Tablets',
              purpose: 'Control blood pressure',
              sideEffects: 'Dizziness, headache',
              storage: 'Store at room temperature',
              alternatives: 'Telma 40',
              isTakenToday: false
            },
            {
              medicineName: 'Amlodipine 5mg',
              dosage: '1 Tablet',
              frequency: 'Once Daily (Night)',
              duration: '30 Days',
              instructions: 'Take before sleep',
              morning: false,
              afternoon: false,
              night: true,
              beforeFood: false,
              afterFood: true,
              quantity: '30 Tablets',
              purpose: 'Control blood pressure',
              sideEffects: 'Ankle swelling',
              storage: 'Store in a cool dry place',
              alternatives: 'Amlopin 5',
              isTakenToday: false
            },
            {
              medicineName: 'Multivitamin Complex',
              dosage: '1 Capsule',
              frequency: 'Once Daily',
              duration: '15 Days',
              instructions: 'Take after meal',
              morning: true,
              afternoon: false,
              night: false,
              beforeFood: false,
              afterFood: true,
              quantity: '15 Capsules',
              purpose: 'Nutritional supplement',
              sideEffects: 'None',
              storage: 'Store below 25°C',
              alternatives: 'Becosules',
              isTakenToday: false
            }
          ],
        },
        {
          prescriptionId: 'RX-2026-442',
          doctorName: 'Dr. Patel',
          qualification: 'MBBS, MD (General Medicine)',
          hospitalName: 'City Care Clinic',
          date: '10 May 2026',
          diagnosis: 'Acute Upper Respiratory Tract Infection',
          doctorNotes: 'Drink warm water and steam inhalation twice daily.',
          status: 'Completed',
          doctorPhoto: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?q=80&w=150',
          validUntil: '15 May 2026',
          testsRecommended: [],
          isFavorite: false,
          rxList: [
            {
              medicineName: 'Amoxicillin 500mg',
              dosage: '1 Capsule',
              frequency: 'Thrice Daily (8hrly)',
              duration: '5 Days',
              instructions: 'Complete full course',
              morning: true,
              afternoon: true,
              night: true,
              beforeFood: false,
              afterFood: true,
              quantity: '15 Capsules',
              purpose: 'Antibiotic for throat infection',
              sideEffects: 'Nausea, diarrhea',
              storage: 'Keep away from moisture',
              alternatives: 'Mox 500',
              isTakenToday: false
            },
            {
              medicineName: 'Paracetamol 650mg',
              dosage: '1 Tablet',
              frequency: 'As needed for fever',
              duration: '5 Days',
              instructions: 'Max 3 tablets per day',
              morning: true,
              afternoon: true,
              night: true,
              beforeFood: false,
              afterFood: true,
              quantity: '10 Tablets',
              purpose: 'Fever and pain relief',
              sideEffects: 'None when taken in limit',
              storage: 'Store below 30°C',
              alternatives: 'Dolo 650',
              isTakenToday: false
            }
          ],
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

  const rajeshCitizen = await Citizen.findOne({ profileId: 'x7k9m2' });
  if (rajeshCitizen) {
    const rawToken = '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918';
    const hashedToken = crypto.createHash('sha256').update(rawToken).digest('hex');
    await NfcCard.create({
      patientId: rajeshCitizen._id,
      hashedToken,
      publicCardId: 'card-uuid-rajesh-12345',
      status: 'active',
    });
    console.log(`✅ Seeded NFC card mapping for Rajesh Kumar (Token: '${rawToken}')`);
  }

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
