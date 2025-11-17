# OpenEar

**Project Title:** OpenEar  
**Team Members:**  
- Villegas, Jean Kathleen R. -Homepage interface and Improving sode Structures ----Architectural and UI Design Model
- Nombrado, John Cale  -Uploading design artifacts and coding the welcome page------Data Design Model and Data Flow Diagram
- Diwa, Francis Marc Nikko G.  - Login interface and fixing bugs-----Procedural Diagram
 

**Date Started:** 09/16/25  
**Expected Completion:** 12/1/25  

---

## 1. Project Overview
OpenEar is a mobile application designed to assist visually impaired learners in accessing study materials in a fully voice-driven environment. While traditional screen readers exist, they are often limited and non-interactive. OpenEar provides an AI-powered voice assistant that can read study materials, answer voice-based questions, and provide interactive quizzes.

---

## 2. Objectives

**Main Goal:**  
Leverage AI virtual assistance to enhance education for visually impaired learners.

**Specific Objectives:**  
- Allow learners to listen to study materials (Text-to-Speech)  
- Enable learners to ask questions by voice (Speech-to-Text)  
- Provide simple quizzes with audio prompts and voice-based answers  
- Ensure the app is fully operable without visual input  

---

## 3. Scope

**In-Scope Features:**  
- Upload or type study materials and have them read aloud.  
- Take quizzes with audio-based questions and voice answers; save scores in CSV files.  
- Fully voice-driven interaction for navigation and usage.  

**Out-of-Scope Features:**  
- Open-ended AI Q&A answering arbitrary questions.  
- Complex graphical interfaces or advanced accessibility beyond voice input/output.  
- Cloud storage or multi-user account management; all data is local.  

---

## 4. Stakeholders

**Primary Users:** Visually impaired learners  

---

## 5. Requirements

### Functional Requirements
1. **Text-to-Speech:**  
   - Read study materials aloud.  
   - Allow users to upload or input notes in text format.  

2. **Speech-to-Text (Voice Input):**  
   - Users can ask questions via voice.  
   - Convert voice to text for processing.  

3. **Quiz Mode:**  
   - Read multiple-choice or true/false questions aloud.  
   - Accept spoken answers and evaluate correctness.  
   - Provide audio feedback for correct/incorrect answers.  

4. **Progress Tracking:**  
   - Record quiz scores and responses.  
   - Store user progress in CSV files.  

5. **Non-Visual Interface:**  
   - Partially voice-operable.  
   - Provide audio prompts for navigation and actions.  

### Non-Functional Requirements
1. **Accessibility:**  
   - No visual interface required.  
   - Use clear, natural-sounding speech.  

2. **Usability:**  
   - Intuitive audio instructions and feedback.  
   - Simple voice commands for all functions.  

3. **Performance:**  
   - Voice input response within 2 seconds.  
   - Minimal delay for TTS and STT operations.  

4. **Reliability:**  
   - Operate correctly for ≥95% of interactions.  
   - ≥85% speech recognition accuracy.  

5. **Security & Privacy:**  
   - Data stored locally and securely.  
   - No unauthorized access to files.  

---

## 6. System Design (High-Level)

### Architecture / Modules
- **Voice Input Module:** Converts voice commands to text; handles actions like “start quiz” or “read notes.”  
- **Text-to-Speech (TTS) Module:** Reads study materials and quiz questions aloud.  
- **Quiz Engine:** Loads questions, asks them aloud, evaluates voice answers.  
- **Progress Tracker (CSV):** Saves and reads quiz results.  
- **File Manager:** Uploads, saves, and manages text notes locally.  
- **User Interface:** Simple Flutter interface optimized for voice-first interaction.  

### Technologies / Tools
| Component          | Technology/Tool                    |
|-------------------|-----------------------------------|
| Framework          | Flutter (Dart)                    |
| Speech Recognition | speech_to_text package             |
| Text-to-Speech     | flutter_tts package                |
| Data Storage       | Local CSV files via csv + path_provider |
| UI Design          | Flutter widgets                    |
| File Access        | File picker, path_provider, dart:io |
| Platform           | Android (primary), iOS (optional) |

---

## 7. Project Timeline
*Start:* 09/16/25  
*End:* 12/1/25  
*Milestones:*  
- Requirements gathering and planning  
- Flutter setup and basic voice interface  
- Implement TTS and STT modules  
- Quiz engine and CSV progress tracking  
- Integration and usability testing  
- Final deployment and demo  

---

## 8. Risks & Mitigation
| Risk | Mitigation |
|------|------------|
| Low voice recognition accuracy in noisy environments or with accents | Use reliable STT plugin and allow retries |
| Robotic or unclear TTS output | Configure flutter_tts for natural voice; allow speed/pitch adjustment |
| File permission/storage issues | Use path_provider for safe paths; handle errors gracefully |
| Limited offline support | Use fully offline-compatible packages and document requirements |

---

## 9. Testing & Quality Plan
**What to Test:**  
- Speech recognition accuracy across environments  
- Text-to-speech clarity for notes and quizzes  
- Quiz functionality and score recording  
- CSV read/write reliability  
- Full voice-only interface usability  

**How to Test:**  
- Manual testing with voice commands in varied conditions  
- Automated unit tests for quiz evaluation and CSV handling  
- Usability testing with visually impaired users  
- Error handling for missing files, invalid input, or denied permissions  
- Performance testing for response times  

---

## 10. Deliverables
- **Working Flutter App:** Voice-driven mobile app for study materials, quizzes, and progress tracking.  
- **Project Documentation:** Problem statement, objectives, system design, and user guide.  
- **Demo Video/Presentation:** Showcasing study material upload, quizzes, and progress tracking.  

---

**Note:** This project prioritizes accessibility for visually impaired learners, leveraging AI-powered voice interactions for educational empowerment.  


