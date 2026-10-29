# Serveo Commercial Restaurant Onboarding Checklist

This internal checklist guides the operations and customer success teams when provisioning, configuring, and verifying a new restaurant client for live production operations.

---

## 1. Restaurant Profile & Identity Setup
- [ ] **Provision Restaurant Record**: Create initial restaurant document with a clean, lowercase URL slug (e.g. `slug: "the-campus-cafe"`).
- [ ] **Branding Assets**:
  - [ ] Upload square restaurant logo (recommended: 512x512 PNG/JPEG, maximum 5MB).
  - [ ] Verify logo fallback behavior if external image URL is temporarily unreachable.
- [ ] **Address & Contact Info**:
  - [ ] Physical street address, campus/food court block, city, and postal code.
  - [ ] Customer support contact telephone and email.
- [ ] **Operating Hours & Schedule**:
  - [ ] Configure active operating days (e.g., Monday through Saturday).
  - [ ] Configure standard opening and closing times (`HH:mm` in 24-hour format).
  - [ ] For late-night venues, verify midnight-crossing schedule (e.g., `18:00` to `02:00`).
  - [ ] Verify restaurant timezone is set to `Asia/Kolkata`.

---

## 2. Staff Accounts & RBAC Assignment
- [ ] **Owner Account**:
  - [ ] Assign primary restaurant owner email/UID in `staff` with role `"owner"`.
  - [ ] Verify owner can access Settings, Staff Management, and Subscriptions.
- [ ] **Operational Staff**:
  - [ ] **Manager**: Assign for menu management, day-to-day order handling, and report viewing.
  - [ ] **Kitchen Staff**: Provision for kitchen display tablets; verify permissions are restricted to viewing live orders and marking them `Preparing` -> `Ready`.
  - [ ] **Cashier Staff**: Provision for counter terminals; verify cashier can access order lookup and payment verification, but cannot edit menu prices or business settings.
- [ ] **Last-Owner Guard Verification**:
  - [ ] Confirm the system prevents accidental removal or demotion of the sole remaining owner.

---

## 3. Menu Catalog & Availability
- [ ] **Category Structure**: Configure logical categories (e.g. Beverages, Snacks, Combos, Desserts).
- [ ] **Item Upload**:
  - [ ] Upload active menu items with accurate base prices (in INR `₹`).
  - [ ] Set dietary badges (`Veg`, `Non-Veg`, `Egg`).
  - [ ] Set preparation time estimates.
- [ ] **Customizations & Add-ons**:
  - [ ] Configure options (e.g. Extra Cheese, Sugar Level, Portion Size) with authoritative backend add-on pricing.
- [ ] **Plan Item Limit Check**:
  - [ ] Verify item count does not exceed the subscribed plan capacity (e.g., Starter: 20 items, Growth: 50 items).

---

## 4. Payment Workflows & Settlement
- [ ] **Manual UPI Payment Setup**:
  - [ ] Configure merchant UPI ID (VPA) and QR display for counter payments.
  - [ ] Instruct cashier staff on transaction reference matching and the verification approval/rejection protocol.
  - [ ] Verify rejection reason guidelines (e.g., "Reference mismatch", "Amount incorrect").
- [ ] **Cash on Delivery (COD)**:
  - [ ] Confirm COD is enabled and kitchen tickets display payment status as `Pending (COD)`.
  - [ ] Verify counter collection handoff via order collection status update.

---

## 5. Public QR Menu Verification
- [ ] **Stable QR Route**:
  - [ ] Generate and test stable QR menu URL (`https://serveo-foods.onrender.com/menu/<restaurant-slug>`).
  - [ ] Scan QR code using both iOS Camera and Android Google Lens.
- [ ] **Public View Security**:
  - [ ] Confirm customer browser menu loads without requiring authentication.
  - [ ] Verify no administrator emails, internal IDs, or credentials appear in public HTML/JSON payloads.
  - [ ] Verify menu browsing is permitted even when the restaurant is closed or ordering is temporarily paused.
- [ ] **Table Stand & Counter Collateral**:
  - [ ] Print QR standees with clear instructions ("Scan to browse menu and order at counter").

---

## 6. End-to-End Test Transaction Flow
- [ ] **Test Order Placement**:
  - [ ] Place a test COD order from a mobile browser or Flutter customer app.
  - [ ] Verify estimated preparation time calculation.
- [ ] **Kitchen Display Verification**:
  - [ ] Check that the order immediately appears in the Admin Live Orders tab.
  - [ ] Kitchen staff marks order as `Preparing`, then `Ready`.
- [ ] **Payment Verification Flow**:
  - [ ] Place a test UPI order; submit transaction reference from customer view.
  - [ ] Review pending verification banner in Admin panel.
  - [ ] Cashier verifies payment; confirm order moves to `Preparing` and customer receives in-app confirmation notification.
- [ ] **Order Collection**:
  - [ ] Mark order as `Collected` at counter.
  - [ ] Verify customer feedback prompt displays and test feedback submission.

---

## 7. Subscription & Commercial Limits
- [ ] **Assign Subscription Tier**:
  - [ ] Select appropriate plan (`Starter`, `Growth`, or `Premium`).
  - [ ] Set contract duration and start/end dates.
  - [ ] If offering trial period, set `trialDays` and verify trial expiration banner.
- [ ] **Confirm Operational Limits**:
  - [ ] Verify staff account ceiling.
  - [ ] Verify menu item ceiling.
  - [ ] Verify advanced analytics access and CSV export permissions.

---

## 8. Backup & Operational Incident Readiness
- [ ] **Verify Backup Logging**: Confirm restaurant records are included in the automated backup inspection.
- [ ] **Support Escalation Contacts**:
  - [ ] Designate primary on-call technical engineer.
  - [ ] Provide restaurant manager with direct support email (`support@serveo.app`) and emergency helpline.
- [ ] **Incident Response SLA**:
  - [ ] High Severity (ordering blocked during active hours): Response within 15 minutes.
  - [ ] Medium Severity (single staff account issue): Response within 2 hours.

