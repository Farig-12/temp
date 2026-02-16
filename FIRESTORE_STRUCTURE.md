# Service Request Feature - Firestore Structure

## Collections

### 1. `service_requests` (Main Collection)

```javascript
{
  "requestId": "auto-generated-doc-id",
  "userId": "user123",
  "userName": "Abdullah Khan",
  "userPhone": "+923001234567",
  "problem": "Bike chain broken",
  "problemCategory": "chain", // engine, brakes, chain, tire, electrical, battery, oil, other
  "description": "The chain broke while riding, needs replacement",
  "photos": ["url1", "url2"], // Firebase Storage URLs (TODO: implement upload)
  "location": {
    "lat": 24.8607,
    "lng": 67.0011,
    "address": "Main Street, Karachi, Pakistan"
  },
  "status": "pending", // pending, bidding, accepted, in-progress, completed, cancelled
  "acceptedMechanicId": null, // filled when bid accepted
  "acceptedBidAmount": null,   // filled when bid accepted
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### 2. `service_requests/{requestId}/bids` (Subcollection - For Future Use)

```javascript
{
  "bidId": "auto-generated-doc-id",
  "mechanicId": "mech456",
  "mechanicName": "Ali Mechanic",
  "mechanicRating": 4.5,
  "bidAmount": 500,
  "estimatedTime": "30 minutes",
  "message": "I can fix this quickly for you",
  "status": "pending", // pending, accepted, rejected
  "createdAt": Timestamp
}
```

## Firestore Indexes (Required for 10km radius queries)

You'll need to create a composite index in Firebase Console:

**Collection:** `service_requests`
**Fields:**
- status (Ascending)
- location.lat (Ascending)
- __name__ (Ascending)

**Note:** The current implementation uses a simple bounding box approach for the 10km radius. For better performance with large datasets, consider using GeoFlutterFire or similar geohashing libraries.

## Security Rules (Add to Firestore Rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Service requests
    match /service_requests/{requestId} {
      // Anyone can read pending requests (for mechanics)
      allow read: if request.auth != null;
      
      // Only authenticated users can create requests
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
      
      // Only the request owner can update/delete
      allow update, delete: if request.auth != null 
                             && resource.data.userId == request.auth.uid;
      
      // Bids subcollection
      match /bids/{bidId} {
        // Anyone can read bids for a request
        allow read: if request.auth != null;
        
        // Only mechanics can create bids
        allow create: if request.auth != null;
        
        // Only bid owner can update/delete
        allow update, delete: if request.auth != null 
                               && resource.data.mechanicId == request.auth.uid;
      }
    }
  }
}
```

## Usage Examples

### Client Side (Post Service Request)
Already implemented in `service_request_screen.dart`

### Mechanic Side (Listen to Nearby Requests)
```dart
// In your mechanic screen
final nearbyRequests = ref.watch(
  nearbyServiceRequestsProvider(
    LocationParams(
      lat: currentLatitude,
      lng: currentLongitude,
      radiusInKm: 10,
    ),
  ),
);

nearbyRequests.when(
  data: (requests) {
    // Show list of nearby requests
  },
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

## TODO for Production
1. **Image Upload**: Implement Firebase Storage upload for photos
2. **Push Notifications**: Notify mechanics when new requests are posted nearby
3. **Real-time Updates**: Add StreamBuilder for request status changes
4. **Bid Management**: Implement bidding UI for mechanics
5. **Distance Display**: Show distance from mechanic to request location
6. **Filters**: Add category and distance filters for mechanics
7. **Request History**: Show user's past requests
8. **Rating System**: Implement mechanic rating after service completion
