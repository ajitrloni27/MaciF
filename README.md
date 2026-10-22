# Namma MedGate

**Namma MedGate** is a mobile app made for doctors and rural healthcare workers. It lets health workers scan a patient's card with their phone and send medical details to hospital doctors—even when the internet is extremely slow, patchy, or cutting out (like rural 2G or satellite).
 

> 💡 **Preparing for a presentation, viva, or interview?** Read [FLOW.md](FLOW.md) for the complete project study guide, problem statement, tool-by-tool breakdown, architecture map, and live demo script.

---

## 💡 Why We Built This

In remote villages, primary health centers, and disaster relief zones:
* Internet connections are weak, drop packets, or shut off completely.
* Standard apps send huge JSON data files that fail to load or get stuck.
* When sending fails halfway, data can get mixed up or lost.

**Namma MedGate fixes this:**
* **Works offline & on weak internet**: Uses smart compression and error-fixing codes so data gets through.
* **Instant card tap**: Reads patient cards with NFC in one second, with a simple manual typing option if NFC isn't available.
* **Safe and honest**: Sends only what changed, never guesses missing numbers, and confirms delivery before saving.
* **Two-way doctor replies**: Doctors at the hospital can review the patient and send advice or prescriptions straight back to the field worker.

---

## 🔄 How It Works (Step-by-Step Flow)

Here is the complete journey of a patient visit from the village clinic to the hospital specialist:

```mermaid
flowchart TD
    A["1. Patient Tap or Manual Form"] --> B["2. Quick Triage & Symptom Check"]
    B --> C["3. Compare with Saved Baseline (Send Only Changes)"]
    C --> D["4. Pack: Compress → Encrypt → Add Backup Parity → Split into Chunks"]
    D --> E["5. Priority Send (Emergency Patients Go First)"]
    E --> F["6. Bad Internet / Weak Signal Transport"]
    F --> G["7. Doctor's Screen Rebuilds Lost Packets Honestly"]
    G --> H["8. Doctor Sends Advice / Prescription Back to Field Worker"]
```

### The 8 Steps in Detail

1. **Patient Intake (NFC or Manual)**:
   * The health worker taps the patient's card against their Android phone.
   * Basic details (Name, Age, Gender, Blood Group, Allergies) and vitals (Blood Pressure, Pulse, Oxygen, Temp) load immediately.
   * If the patient doesn't have a card, the worker can type it into a simple form.

2. **Quick Triage & Symptom Check**:
   * The app asks simple questions across 5 areas (Chest Pain, Stroke/Nerve signs, Breathing trouble, Bleeding/Injury, General illness).
   * If there are danger signs (like severe chest pain or breathing trouble), it automatically marks the case as **Urgent** and picks the right department (like Cardiology or Pulmonology).

3. **Send Only What Changed (Delta Check)**:
   * Instead of sending the full medical record every time, the app checks what changed since the last confirmed visit.
   * If only blood pressure changed, it sends only the new blood pressure numbers. This cuts data size by up to 85%.
   * The new data is marked as **Pending** in local phone storage until the doctor successfully receives it.

4. **Shrink, Lock, and Add Backups**:
   * The app puts data into a compact list without repetitive labels.
   * It shrinks the data using GZIP compression.
   * It locks the data with AES-256 encryption for patient privacy.
   * It creates backup math pieces (parity). If bad internet drops a packet, the receiver can reconstruct the missing piece without asking to re-send.

5. **Priority Queue (Urgent Cases First)**:
   * Emergency patient records jump to the front of the line.
   * Critical vital signs are always sent before heavy pictures.

6. **Weak Signal & Chaos Simulator**:
   * The app has a built-in internet simulator to test real-world village conditions: 2G/EDGE, high packet loss (up to 80%), and delays.

7. **Doctor Review & Image Rebuild**:
   * At the hospital, the doctor's screen receives packets as they arrive.
   * If chunks were lost on the way, the app rebuilds them using the backup parity pieces.
   * If too much was lost to fix, it tells the doctor honestly instead of guessing wrong numbers.
   * Photos (like wounds or rash pictures) are rebuilt tile by tile.

8. **Doctor Replies Back to the Field**:
   * The doctor writes their diagnosis, advice, and medicine orders.
   * This reply travels back using the same protected pipeline.
   * An alert pops up on the field worker's phone.
   * Once confirmed, the record is safely saved into the permanent database.

---

## ✨ Key Features in Detail

### 1. Contactless NFC Patient Card Scan
Health workers do not need to type lengthy patient details every time. They simply tap the patient's smart card against an Android phone. The app instantly reads demographics (Name, Age, Gender, Blood Group), vital signs (Blood Pressure, Heart Rate, Oxygen level, Temperature), and any known allergies. Health workers can also write updated diagnosis notes and prescriptions directly back onto the card so the patient can carry their updated records anywhere.

### 2. Simple Manual Entry Fallback
If the patient does not have an NFC card, or if NFC hardware is turned off, the app provides a clean, easy-to-use form. The screen lets workers quickly enter patient details with helpful input checks that warn if a vital sign looks unusually high or low (such as an impossible blood pressure or fever).

### 3. Rule-Based Symptom Triage & Emergency Flags
Frontline clinics need to spot dangerous emergencies immediately. The app walks workers through a quick symptom questionnaire covering five key health areas:
* **Heart & Chest**: Checks for crushing chest pain, pain spreading to the arm, or heavy sweating.
* **Brain & Nerves**: Checks for sudden weakness, face drooping, or trouble speaking.
* **Lungs & Breathing**: Checks for shortness of breath or blue lips.
* **Bleeding & Injuries**: Checks for deep cuts, broken bones, or head trauma.
* **General Infection**: Checks for very high fever or severe dehydration.

If danger signs appear, the app immediately flags the visit as **Urgent** and automatically picks the matching hospital specialty (such as Cardiology, Neurology, or Pulmonology).

### 4. Smart Delta Sync (Send Only What Changed)
Traditional apps re-send the patient's entire medical record on every visit, wasting valuable data. MedGate compares the new visit with the patient's last confirmed record in the database and sends *only the specific fields that changed*. If only the patient's blood pressure was adjusted, only the new blood pressure numbers travel over the wire, cutting data size by up to 85%.

### 5. Self-Healing Packets (Forward Error Correction)
When internet signals cut out or drop packets, standard apps freeze and fail. MedGate groups data packets and generates backup recovery math pieces (called parity). Even if 20% to 40% of the packets vanish in transit, the doctor's receiver can mathematically rebuild the missing pieces without needing to re-download or re-send anything.

### 6. Honest Math & Safe Confidence Scoring
Medical care cannot rely on guessing. MedGate measures exact recovery mathematically:
* If all pieces or enough backup parity pieces arrive, the record is verified and marked 100% recovered.
* If damage is too severe and exceeds the backup capacity, MedGate honestly tells the doctor: *"Recovery Incomplete — Please Reconnect"*. It never fabricates or guesses missing vital numbers.

### 7. Store-and-Forward Queue with Urgent Priority
If the internet dies completely, the app does not lose your work. Patient visits are safely stored in an offline queue:
* When internet returns, items send automatically in the background.
* High-risk and emergency visits automatically jump to the front of the line ahead of routine checkups.
* Vital signs are always sent first before large photos or media.

### 8. Two-Way Doctor Consultation & Orders
Telemedicine should not be a one-way street. Once the specialist reviews the patient's vitals, triage flags, and photos, they can write their diagnosis, medication orders, and immediate next steps. This reply travels back through the same compressed, secure pipeline, popping up as an instant alert banner on the frontline worker's phone.

### 9. Built-in Bad Internet Simulator
To prove the system works under real-world conditions, the app includes a live test lab. You can slide sliders to simulate 10% to 80% packet loss, high latency (up to 4 seconds), and weak bandwidth presets (like 2G/EDGE or satellite). You can watch real packets drop, survive, and get mathematically rebuilt on screen in real time.

---

## 📦 How Data Travels (The 5-Step Pipeline)

To make data as small, safe, and tough as possible, every outgoing message follows this exact order:

```
[Patient Data]
      │
      ▼
1. Short Format        --> Removes repetitive field names. Example: "P01|John|45|M|120|80"
      │
      ▼
2. GZIP Shrink         --> Makes the text as small as possible (saves 40-70% size).
      │
      ▼
3. AES-256 Lock        --> Encrypts the shrunken data so nobody can spy on it.
      │
      ▼
4. Backup Math Pieces  --> Creates parity pieces to fix packets that get lost in transit.
      │
      ▼
5. Split into Chunks   --> Breaks data into small bite-sized packets ready for weak signals.
      │
      ▼
 [Sent over Network]
```

---

## 🧠 Smart Design Choices

* **Why compress BEFORE encrypting?**  
  Encrypted data looks completely random. Random data cannot be compressed. By compressing *first*, we shrink the data down before locking it.
* **Why no JSON tags?**  
  Words like `"patient_name"` and `"blood_pressure"` take up most of the bytes. We send values in a fixed position instead, saving huge amounts of data.
* **Why "Compare-Then-Overwrite"?**  
  If a phone sends an update but the internet dies halfway, the phone keeps the old confirmed record safe. It only marks the new record as confirmed once the doctor's screen verifies it.
* **Honest Math, No Guesses:**  
  In healthcare, wrong data is dangerous. If a connection is too broken to rebuild lost pieces, the app says "Recovery Failed — Please Reconnect" rather than showing guessed vitals.

---

## 📁 Project Structure

```
cih_2026-main/
├── lib/
│   ├── core/                  # Shared styling, glass cards, alert banners, and page router
│   │   ├── routing/           # Page navigation
│   │   ├── theme/             # Modern glassmorphism UI theme
│   │   └── widgets/           # Reusable alerts (ClinicalAlert) and badges (StatusPill)
│   ├── features/
│   │   ├── home/              # Main dashboard for health workers
│   │   ├── nfc_capture/       # NFC card reading, card writing, and manual form
│   │   ├── triage/            # 5-domain symptom questionnaire and emergency routing
│   │   ├── transmission_engine/# 5-step pipeline, compression, encryption, and recovery
│   │   ├── network_simulator/ # Internet condition tester (loss %, latency, presets)
│   │   ├── specialist_view/   # Doctor's console, tile reassembly, and reply composer
│   │   └── patient_storage/   # SQLite database with safe compare-then-overwrite rules
│   └── main.dart              # App startup
├── test/                      # 63 automated tests for all features and math
├── Dockerfile                 # For running tests in a clean container
└── AGENTS.md                  # Development rules and coding guidelines
```

---

## 🚀 How to Run the App

### Requirements
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (version 3.24 or newer).
* An Android phone, iPhone, or Chrome browser.

### 1. Download and install dependencies
```bash
flutter pub get
```

### 2. Start the app
```bash
flutter run
```

### 3. Quick Tryout
1. Open the app and choose **New Patient Intake**.
2. Tap **Scan NFC Tag** or toggle **Manual Mode** to fill sample vitals.
3. Check some symptoms in **Triage** (like chest pain) to see the emergency flag.
4. Go to **Network Simulator**, turn packet loss up to **40%**, and hit Send.
5. Open the **Specialist View** to watch the packets rebuild and read the patient record.
6. Type a doctor reply and send it back to see the alert on the worker's screen.

---

## 🧪 Running Tests

MedGate includes **63 automated tests** that check everything from data compression to packet recovery and database rules.

Run all tests with:
```bash
flutter test
```

Check code health with:
```bash
flutter analyze
```

Or run everything inside Docker:
```bash
docker compose run medgate-dev flutter test
```
