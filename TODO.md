# TODO: Fix Connection Timeout Issue

## Changes Made:
- [x] Updated baseUrl in frontend/corn_app/lib/core/config/env.dart to use local IP (192.168.0.101:8000)
- [x] Added 60-second timeout to API client in frontend/corn_app/lib/core/api/api_client.dart
- [x] Changed backend to run on 0.0.0.0:8000 in backend/app.py

## Next Steps:
- [ ] Start the backend server: `cd backend && python app.py`
- [ ] Build and run the Flutter app on the phone
- [ ] Test image upload and analysis from the phone
- [ ] Ensure phone and server are on the same WiFi network
