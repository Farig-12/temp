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

### 2. `service_requests/{requestId}/bids` (Subcollection - IMPLEMENTED)

```javascript
{
  "bidId": "auto-generated-doc-id",
  "requestId": "req123",  // Parent request ID for reference
  "mechanicId": "mech456",
  "mechanicName": "Ali Mechanic",
  "mechanicPhone": "+923001234567",
  "bidAmount": 500,       // Price in PKR
  "message": "I can fix this quickly for you",  // Optional message from mechanic
  "status": "pending",    // pending (default), accepted, rejected
  "createdAt": Timestamp
}
```

**Implementation Details:**
- Mechanics can place bids on pending requests via "Place Bid" button
- Bids are stored as a subcollection under each request
- Users can view all bids on their requests in real-time
- Multiple mechanics can bid on the same request
- Bid includes mechanic's name, phone, and bid amount

## Firestore Indexes (Required for 10km radius queries)

You'll need to create composite indexes in Firebase Console:

### 1. Service Requests Index (for nearby queries)
**Collection:** `service_requests`
**Fields:**
- status (Ascending)
- location.lat (Ascending)
- __name__ (Ascending)

### 2. User Requests & Bids Indexes (NOT REQUIRED)
All user-side queries have been optimized to avoid index requirements:
- `getUserServiceRequests`: Uses only `where('userId')`, sorts in memory
- `getBidsForRequest`: No filters, sorts in memory
- This eliminates the need for composite indexes on these queries

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
Implemented in `service_request_screen.dart`
- Users can create service requests with photos and location
- Users can view their requests in `my_service_requests_screen.dart`
- Users see live bids from mechanics on their requests

### Mechanic Side (Place Bids on Requests)
Implemented in `mechanic_home_screen.dart`
- Mechanics view all pending service requests
- Click "Place Bid" button to bid on a request
- Enter bid amount (PKR) and optional message
- Bids are sent to Firestore and appear live on user's screen

### Viewing Bids (User Side)
Implemented in `my_service_requests_screen.dart`
```dart
// Navigate from service request screen
route.push(getRoutePath(myServiceRequestsRoute));

// Bids are streamed live using bidsForRequestProvider
final bids = ref.watch(bidsForRequestProvider(requestId));
```

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
4. ✅ **Bid Management**: Implement bidding UI for mechanics (COMPLETED)
5. **Distance Display**: Show distance from mechanic to request location
6. **Filters**: Add category and distance filters for mechanics
7. ✅ **Request History**: Show user's past requests (COMPLETED)
8. **Rating System**: Implement mechanic rating after service completion
9. **Accept/Reject Bids**: Allow users to accept or reject bids
10. **Payment Integration**: Add payment flow after accepting a bid
