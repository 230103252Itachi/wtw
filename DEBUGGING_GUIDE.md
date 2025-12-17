# Debugging Guide - AI Data Flow

## Problem
AI characteristics not appearing in Wardrobe UI despite all code being implemented.

## What We Did
1. ✅ Deployed Firestore Security Rules (firestore.rules)
2. ✅ Updated firebase.json with firestore config
3. ✅ Created firestore.indexes.json
4. ✅ Added comprehensive debug logging throughout the stack

## How to Debug

### Step 1: Run the App
```bash
flutter run -v
```

### Step 2: Add a New Wardrobe Item
1. Tap "Add Item"
2. Select or take a photo
3. Enter title/category
4. Tap Save
5. Watch console logs

### Expected Log Sequence

#### Phase 1: Local Save (Immediate)
```
[AddItem] Saving image locally...
[AddItem] Local save complete, closing screen...
[AddItem] Starting Firebase upload in background...
```

#### Phase 2: Firebase Upload (Background)
```
[BG] ⏳ Starting background upload and AI processing...
[BG] 🚀 Background async started
[BG] 📤 Starting Firebase upload...
[Firebase] Starting upload for user: {uid}
[Firebase] Generated itemId: {itemId}
[Firebase] Uploading photo to Storage...
[Firebase] Photo uploaded successfully. URL: {photoUrl}
[Firebase] Saving metadata to Firestore...
[Firebase] ✅ Metadata saved successfully
[BG] ✅ Firebase upload complete, itemId={itemId}
[BG] ⏱️ Waiting 1000ms before AI processing...
```

#### Phase 3: AI Processing (After 1000ms wait)
```
[BG] 🤖 Starting AI processing with itemId={itemId}...
[AI] 📸 process start for {filePath}, itemId={itemId}
[AI] 🗜️ Compressing image...
[AI] 🔍 Calling OpenAI describeClothes...
[AI] ✅ describe result: {category, colors, material, style_tags, pattern, warmth, notes}
[AI] 💾 Updating Firestore document {itemId} with AI data...
[AI] 💾 Data to save: {fullData}
[Firebase] 🤖 Updating item {itemId} with AI data...
[Firebase] ✅ Item {itemId} updated with AI data successfully
[AI] ✅ Firestore document updated successfully
[BG] ✅ AI processing complete
[BG] 🏁 Background async ended
```

#### Phase 4: UI Update (Stream Listener)
```
[Wardrobe] 📡 Snapshot received: {newDocCount} docs
[Wardrobe] 📦 Item {itemId}: title={title}, AI_data=true
[Wardrobe]   ✅ Category={category}, Colors={colors}, Material={material}
[Wardrobe] ✅ Loaded {totalItems} items from Firebase snapshot
```

### Debugging Steps

#### If you see [BG] but NOT [Firebase]:
- Problem: Firebase upload not starting
- Check: FirebaseWardrobeService.instance is initialized
- Check: FirebaseAuth is properly authenticated

#### If you see [Firebase] but NOT [AI]:
- Problem: AI processing not starting
- Check: itemId is not null/empty
- Check: 1000ms wait completed

#### If you see [AI] but fails on OpenAI call:
- Problem: OpenAI API issue
- Check: API key is correct in ai_stylist_service.dart
- Check: Image compression works
- Check: Network timeout (30 seconds)

#### If you see [Firebase] update but NOT [Wardrobe] snapshot:
- Problem: Stream listener not receiving updates
- Check: Firestore Rules are deployed ✅ (we just did this)
- Check: User is authenticated correctly
- Check: Path is correct: `users/{uid}/wardrobe/{itemId}`

#### If you see [Wardrobe] snapshot but UI still shows "Pending AI analysis...":
- Problem: Metadata not properly extracted
- Check: Field names match exactly: category, colors, material, style_tags, pattern, warmth, notes
- Check: wardrobe_screen.dart previewText() method
- Check: Item details modal shows all AI fields

## Files to Check

### Main Files in Data Flow
1. **lib/screens/add_item_screen.dart** - Entry point
   - `_saveItem()` - Calls local save and background upload
   - `_uploadAndProcessInBackground()` - Starts async flow
   - `_uploadAndProcessBackgroundAsync()` - Uploads to Firebase
   - `_processAndCacheImage()` - AI processing

2. **lib/services/firebase_wardrobe_service.dart** - Firebase Operations
   - `uploadItemWithPhoto()` - Photo + metadata upload
   - `updateItemWithAIData()` - AI data update

3. **lib/models/wardrobe_model.dart** - State Management
   - `_initializeFirebaseListener()` - Stream listener setup
   - `_loadItemsFromSnapshot()` - Process updates

4. **lib/screens/wardrobe_screen.dart** - UI Display
   - `previewText()` - Shows AI info or "Pending..."
   - Item details modal

5. **firestore.rules** - Security Rules (JUST DEPLOYED ✅)

## Firebase Configuration
- Project: itachi-wtw
- Firestore Database: default (europe-west1)
- Collection Structure:
  ```
  users/
    {userId}/
      wardrobe/
        {itemId}/  <- Document with photo, title, photoUrl, AND AI fields
      outfits/
        {outfitId}/
  ```

## Known Issues Fixed
1. ✅ Firestore Rules not deployed - FIXED by deploying
2. ✅ firebase.json missing firestore config - FIXED by adding firestore section
3. ✅ Background async using unreliable .ignore() - FIXED by direct call
4. ✅ rethrow blocking itemId return - FIXED by removing rethrow
5. ✅ .update() not reliable - FIXED by using .set(merge: true)

## Next Steps If Still Not Working
1. Run app with `-v` flag and search for `[BG]`, `[Firebase]`, `[AI]`, `[Wardrobe]` in logs
2. Share complete log output for the flow from adding item to expecting AI data
3. Check Firebase Console > Firestore to verify data structure matches expected
4. Check Authentication tab to confirm user is logged in
5. Run `firebase emulator:start` to test with local emulator if issues persist
