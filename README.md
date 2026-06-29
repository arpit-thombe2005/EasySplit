# EasySplit

**Lightweight, zero-storage expense sharing for friends and groups** — a production-ready Flutter application built with Clean Architecture, Riverpod, GoRouter, and a Node.js/Neon PostgreSQL backend.

---

## Highlights & Philosophy

- ⚡ **Zero Cloud File Storage** — No camera/gallery permissions, no image uploads, and zero storage costs.
- 🎨 **Built-in Avatar Collection** — 16 vibrant minimalist avatar presets rendered completely offline via `avatar_id`. Randomly assigned at registration and customizable anytime.
- 📱 **Lightweight & Free** — Simplified infrastructure keeping EasySplit completely free and fast.

---

## Features

- 📱 **Authentication** — Email OTP login (custom Nodemailer), persistent sessions
- 👥 **Groups** — Create, edit, delete, invite members by email, leave groups  
- 💸 **Expenses** — Add/edit/delete with Equal, Exact, Percentage, and Shares splits
- 🧮 **Debt Simplification** — Min-cash-flow greedy algorithm minimizes transactions
- 📊 **Dashboard** — Net balance, owe/owed summary, quick actions
- 🔔 **Activity** — Expense and settlement timeline
- 👤 **Profile** — Built-in avatar selection, currency selection, theme preference
- 🌙 **Dark Mode** — Full Material 3 dark theme

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | Flutter 3.x, Material 3 |
| State | Riverpod + Freezed |
| Navigation | GoRouter |
| Backend | Node.js / Express |
| Database | Neon PostgreSQL |
| Email | Nodemailer (custom SMTP) |
| Auth | JWT (stateless) |

---

## Project Structure

```
easy_split/
├── lib/
│   ├── core/
│   │   ├── constants/       # App constants, avatar presets, routes, enums
│   │   ├── theme/           # Material 3 light/dark themes
│   │   ├── router/          # GoRouter with auth guards
│   │   ├── services/        # API service, Auth session
│   │   └── utils/           # Debt simplification, currency formatter
│   ├── features/
│   │   ├── auth/            # Email login, OTP, sign up with avatar selection
│   │   ├── groups/          # Groups CRUD, member management
│   │   ├── expenses/        # Expense CRUD, split calculator
│   │   ├── settlements/      # Debt tracking, settlements
│   │   ├── activity/        # Timeline, notifications
│   │   ├── home/            # Dashboard
│   │   └── profile/         # Profile, settings, built-in avatar selector
│   └── shared/
│       └── widgets/         # Reusable UI components (AppAvatar, AppButton, etc.)
├── backend/
│   ├── routes/              # Express routes (auth, groups, expenses, settlements)
│   ├── db.js                # Neon connection
│   ├── index.js             # Express server entry
│   └── schema.sql           # PostgreSQL schema (users with avatar_id)
└── assets/
    ├── icons/
    └── fonts/
```

---

## Setup

### 1. Neon Database

1. Create a project at [neon.tech](https://neon.tech)
2. Copy your connection string
3. Run `backend/schema.sql` in the Neon SQL editor

### 2. Backend

```bash
cd backend
cp .env.example .env
# Fill in DATABASE_URL, JWT_SECRET, SMTP credentials in .env
npm install
npm run dev
```

### 3. Flutter App

```bash
# Install dependencies
flutter pub get

# Generate Freezed/JSON code
flutter pub run build_runner build --delete-conflicting-outputs

# Run app
flutter run
```

---

## Debt Simplification Algorithm

EasySplit implements a **Min-Cash-Flow** greedy algorithm (`lib/core/utils/debt_simplification.dart`) that:

1. Aggregates all raw transactions into net balances
2. Separates creditors (+) and debtors (-)
3. Greedily matches the largest creditor with the largest debtor
4. Returns the minimum number of transactions to settle all debts
