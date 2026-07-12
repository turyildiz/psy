## 3. User & Profile Architecture (The "Umbrella" Model)

### 3.1 Overview
Psy.market utilizes a **One-to-Many (Parent-Child)** relationship between Accounts and Public Profiles. This architecture separates the *Legal Entity* (User) from the *Public Persona* (Profile), allowing a single user to manage multiple distinct identities (e.g., a "Personal Buyer" profile, a "DJ Artist" profile, and a "Record Label" profile) without multiple logins.

### 3.2 Core Concepts

#### Level 1: The Master Account (`User`)
* **Definition:** The authentication record and legal owner of the account.
* **Visibility:** strictly **Private**. No other user sees this entity.
* **Key Data:** Email, Password (hashed), Date of Birth, Stripe Connect ID (KYC/Identity Verification).
* **Function:** Handles login, security, and financial payouts.
* **Cardinality:** 1 per human/company.

#### Level 2: The Personas (`Profile`)
* **Definition:** The public-facing identity used to interact with the marketplace.
* **Visibility:** **Public**.
* **Key Data:** Handle (URL), Display Name, Avatar, Header Image, Bio, Reputation (Reviews).
* **Function:** Handles listing products, buying items, sending messages, and collecting followers.
* **Cardinality:** N (Unlimited) per Master Account.

---

### 3.3 User Stories & Use Cases

**Case A: The "Hybrid" User (John Doe)**
> *As John, I want to buy a second-hand jacket without my fans knowing, but I also want to sell my DJ mixes under my artist name.*
* **Solution:** John creates a default "Personal" profile for buying. He creates a second "Artist" profile (`@dj-jd`) for selling. His purchase history is linked to his Personal profile; his sales history is linked to his Artist profile.

**Case B: The Professional Vendor (Printing Co.)**
> *As a merchandise printer, I manage shops for 3 different festivals. I need to switch between them easily to fulfill orders.*
* **Solution:** The user logs in once. They use a "Profile Switcher" in the dashboard to toggle between `@psy-fi-shop`, `@ozora-merch`, and `@my-print-shop`. All notifications are centralized but tagged by profile.

---

### 3.4 Functional Requirements

#### 3.4.1 Registration & Onboarding
1.  User signs up via Email/Social (creates `auth.users` record).
2.  System automatically generates **one default profile** (Type: `Personal`) using the user's name.
3.  User is redirected to the "Select Profile" or "Feed" view.

#### 3.4.2 Creating Additional Profiles
* User can select "Create New Profile" from the settings menu.
* **Required Fields:**
    * **Type:** `Buyer` (Default), `Artist` (DJ/Producer), or `Vendor` (Shop/Label).
    * **Handle:** Unique string (e.g., `psy.market/shop/astrix`).
    * **Display Name:** Public name.
* **Validation:** Handle must be unique across the entire platform.

#### 3.4.3 Profile Switching (Session Management)
* The frontend must maintain an `activeProfileId` in the application state.
* All actions (Listing an item, Sending a message, Liking a product) must tag the `activeProfileId`, **not** just the `userId`.
* **UI:** A dropdown menu in the navbar displaying the avatar of the currently active profile.

#### 3.4.4 Financial Inheritance (Stripe Connect)
* **KYC (Know Your Customer)** is performed strictly on the **Master Account (`User`)**.
* **Wallet Logic:** Revenue from *all* profiles flows into the single Stripe Connect account linked to the Master User.
* *Benefit:* A user verifies their passport once. They can then open 5 different shops (Profiles) without re-verifying identity for each one.

---

### 3.5 Data Model (Schema Specification)

**Table: `public.profiles`**
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | UUID | Primary Key (The Profile ID). |
| `user_id` | UUID | Foreign Key to `auth.users`. (The Owner). |
| `type` | ENUM | `personal`, `artist`, `label`, `festival`. |
| `handle` | TEXT | Unique slug for URLs (e.g. "ace-ventures"). |
| `display_name` | TEXT | The name shown on the storefront. |
| `bio` | TEXT | Description/About section. |
| `avatar_url` | TEXT | Link to image storage (Supabase/UploadThing). |
| `header_url` | TEXT | Link to profile banner image. |
| `is_verified` | BOOL | Manual "Blue Check" for big artists/festivals. |

---

### 3.6 Future Considerations (V2+)
* **Team Access:** Allow *multiple* Master Users to manage a single Profile (e.g., a Festival profile managed by 3 staff members).
* **Reputation Isolation:** Ensure negative reviews on a "Vendor" profile do not affect the "Personal" buying profile of the same user.