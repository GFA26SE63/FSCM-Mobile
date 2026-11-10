Retailer orders awaiting prepaid payment now keep checkout and status actions visible, with a confirmed switch to approved credit when no money has been received and no PayOS transaction exists. Order headers use the business order code, promotion labels use human names, and batch expiry comes from allocationFragments.

Depends on Mobile #41 and Backend GFA26SE63/FSCM-Backend#105 (stacked on Backend #104). Active PayOS transactions require confirmed cancellation before switching.

Validation: flutter analyze clean, all 39 Flutter tests passed, Android debug APK built. Shared demo database fallback tested on DH-001058, creating exactly one PO on retry. DH-001057 remains prepaid.
