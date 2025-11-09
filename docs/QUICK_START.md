# Crusade Campaign Tracker - Quick Start Guide

**Get up and running in 5 minutes!**

---

## 🚀 Installation

1. Subscribe to the mod on Steam Workshop _(link TBD)_
2. Load Tabletop Simulator
3. Go to **Objects** → **Saved Objects** → **Workshop**
4. Spawn the **Crusade Campaign Tracker** object
5. The setup wizard will appear automatically!

---

## ⚙️ Campaign Setup (2 minutes)

### Step 1: Campaign Details
- **Name**: Enter your campaign name
- **Supply Limit**: Leave at 50 (or customize)
- Click **Next**

### Step 2: Map (Optional)
- **Skip** for now, or set map size (10×8 recommended)
- Click **Next**

### Step 3: Players
- Add each player: **Name**, **Faction**, **Color**
- Click **Add Player** for each
- Click **Next** when done

### Step 4: Mission Pack (Optional)
- **Skip** for standard Crusade
- Click **Next**

### Step 5: Create
- Review settings
- Click **Create Campaign**
- Done! 🎉

---

## 📋 Adding Your First Unit

**Method 1: Manual Entry**
1. Click **"Manage Forces"**
2. Select your player
3. Click **"Add Unit"**
4. Fill in: Name, Type, Role, Points
5. Toggle flags: CHARACTER, TITANIC, etc.
6. Click **"Save"**

**Method 2: Import from New Recruit** (Faster!)
1. Go to [newrecruit.eu](https://www.newrecruit.eu)
2. Build your unit
3. Click **Export** → Copy JSON
4. In the tracker, click **"Import from New Recruit"**
5. Paste JSON → **"Import"**
6. Done!

---

## ⚔️ Recording Your First Battle

1. Click **"Record Battle"**

### Step 1: Setup
- **Mission Type**: Select mission
- **Battle Size**: Combat Patrol / Incursion / Strike Force / Onslaught
- **Participants**: Check players involved
- **Deploy Units**: Select which units fought
- Click **Next**

### Step 2: Results
- **Winner**: Select winner (or draw)
- **Victory Points**: Enter final VP
- **Destroyed Units**: Mark any destroyed units
- **Combat Tallies**: Enter kills for each unit
- Click **Next**

### Step 3: Post-Battle (AUTOMATIC!)
- ✅ **XP awarded automatically**:
  - All units get +1 XP (Battle Experience)
  - Every 3 kills = +1 XP (calculated for you)
  - Each player selects 1 unit for +3 XP (Marked for Greatness)

- ✅ **Out of Action tests** (for destroyed units):
  - Roll D6 for each
  - On 1: Choose Devastating Blow or Battle Scar
  - On 2-6: Unit survives!

- ✅ **RP awarded**:
  - Loser: +1 RP
  - Winner: +2 RP (+3 if TITANIC destroyed)

### Step 4: Finish
- Review summary
- Click **"Complete Battle"**
- All data saved automatically! 💾

---

## 🏆 Battle Honours (When Units Rank Up)

When a unit ranks up, give them a Battle Honour:

1. Click **"Battle Honours"**
2. Select your unit
3. Choose category:

**Battle Traits** (+1 CP each)
- 12 generic options + faction-specific
- Examples: Inspiring Leader, Lethal Sharpshooter

**Weapon Modifications** (+1 CP each)
- Roll 2D6 for TWO modifications
- Rending, Blazing, Venomous, etc.

**Crusade Relics** (CHARACTER only!)
- **Artificer** (+1 CP): Any rank
- **Antiquity** (+2 CP): Rank 3+
- **Legendary** (+3 CP): Rank 5 only

---

## 💰 Spending RP (Requisitions)

Click **"Requisitions"** to spend RP:

| Requisition | Cost | Effect |
|-------------|------|--------|
| **Increase Supply Limit** | 1 RP | +5 PL to limit |
| **Renowned Heroes** | 1-3 RP | Give a Battle Honour |
| **Legendary Veterans** | 3 RP | Remove 30 XP cap |
| **Rearm and Resupply** | 1 RP | Remove 1 scar |
| **Repair and Recuperate** | 1-5 RP | Restore destroyed unit |
| **Fresh Recruits** | 1-4 RP | Add unit with XP |

---

## 📊 Crusade Points Formula

**CP = floor(XP/5) + Honours - Scars**

### Example:
- Unit has 12 XP
- 2 Battle Traits (+1 CP each)
- 1 Battle Scar (-1 CP)

**Calculation:**
- floor(12/5) = 2 CP (from XP)
- +2 CP (from honours)
- -1 CP (from scar)
- **= 3 CP total**

---

## 📈 XP & Rank Progression

| XP | Rank | Title |
|----|------|-------|
| 0-5 | 1 | Battle-ready |
| 6-11 | 2 | Blooded |
| 12-17 | 3 | Battle-hardened |
| 18-23 | 4 | Heroic |
| 24-30 | 5 | Legendary |

**Rank-Up Trigger**: Every 6 XP

**XP Caps**:
- Non-CHARACTER: 30 XP max
- CHARACTER: Unlimited
- Legendary Veterans: Unlimited (after requisition)

---

## 🗺️ Territory System (If Using Map)

### Claiming Territory
1. Win a battle on a hex
2. Click **"Map Controls"**
3. Select the hex
4. Click **"Claim"**
5. Territory is yours!

### Territory Bonuses
- Configure bonuses for strategic hexes
- Types: RP, Resources, Honours, Custom

---

## 💾 Saving & Loading

**Auto-Save**: Every 5 minutes ✅

**Manual Save**: Click **"Save Campaign"**

**Backups**: Last 10 saves stored automatically

**Export**: **"Export/Import"** → Choose format
- Full Campaign (JSON)
- Player Data
- Units Only

---

## ⚠️ Important Rules

### Battle Scars Limit
- **Maximum 3 scars** per unit
- 4th scar = **Permanent destruction!**
- Use **"Rearm and Resupply"** (1 RP) to remove scars

### Out of Action Results
- **1 on D6**: Choose consequence
  - **Devastating Blow**: Remove 1 honour (if no honours → destroyed!)
  - **Battle Scar**: Gain 1 scar (max 3)
- **2-6**: No effect

### Supply Limit
- Default: **50 PL**
- Going over is allowed but discouraged
- Increase limit with **"Increase Supply Limit"** (1 RP = +5 PL)

---

## 🛠️ Troubleshooting

**Campaign won't load?**
→ Check Campaign_History notebook for backups

**CP calculation wrong?**
→ TITANIC units have doubled honour costs

**Unit disappeared?**
→ Check if it was permanently destroyed (3 scars + Devastating Blow)

**Supply bar is red?**
→ You're over your limit! Remove units or increase limit

---

## 📚 Learn More

- **Full User Guide**: [USER_GUIDE.md](USER_GUIDE.md)
- **Technical Docs**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Deployment**: [DEPLOYMENT.md](DEPLOYMENT.md)

---

## 🎮 Quick Tips

1. **Save after every battle** - Don't lose progress!
2. **Track Agendas** - They grant free honours
3. **Plan your RP spending** - It's limited!
4. **Use New Recruit import** - Much faster than manual entry
5. **Monitor your scars** - 3 is the limit!
6. **Check validation reports** - Catch errors early

---

**Ready to Crusade? Let's go! ⚔️**

For support, visit: [GitHub Issues](https://github.com/arkraven000/CrusadeTracker/issues)
